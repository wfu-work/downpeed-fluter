package httpprotocol

import (
	"context"
	"errors"
	"fmt"
	"net"
	nethttp "net/http"
	"net/url"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/wfu-work/downpeed-fluter/backend/internal/download"
	"golang.org/x/net/proxy"
)

const (
	proxyTestURL       = "https://example.com/"
	maxProxyPassword   = 1024
	proxyTestExtraTime = 5 * time.Second
)

type roundTripperHolder struct {
	transport *nethttp.Transport
}

// ProxyRuntime swaps the transport selected for new requests. Responses that
// are already streaming retain the transport and connection that created them.
type ProxyRuntime struct {
	mu       sync.Mutex
	settings download.ProxySettings
	password string
	current  atomic.Pointer[roundTripperHolder]
}

func NewProxyRuntime(settings download.ProxySettings) (*ProxyRuntime, error) {
	runtime := &ProxyRuntime{settings: settings}
	if err := runtime.rebuildLocked(); err != nil {
		return nil, err
	}
	return runtime, nil
}

func (r *ProxyRuntime) RoundTrip(request *nethttp.Request) (*nethttp.Response, error) {
	holder := r.current.Load()
	if holder == nil || holder.transport == nil {
		return nil, errors.New("HTTP transport is unavailable")
	}
	return holder.transport.RoundTrip(request)
}

func (r *ProxyRuntime) ApplySettings(settings download.ProxySettings) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.settings = settings
	_ = r.rebuildLocked()
}

func (r *ProxyRuntime) SetPassword(password string) error {
	if len(password) > maxProxyPassword || strings.ContainsRune(password, '\x00') {
		return download.ErrInvalidProxySettings
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	r.password = password
	return r.rebuildLocked()
}

func (r *ProxyRuntime) Test(ctx context.Context) (download.ProxyTestResult, error) {
	r.mu.Lock()
	settings := r.settings
	r.mu.Unlock()
	timeout := time.Duration(settings.ConnectTimeoutSeconds+settings.ResponseHeaderTimeoutSeconds)*time.Second + proxyTestExtraTime
	testCtx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	request, err := nethttp.NewRequestWithContext(testCtx, nethttp.MethodHead, proxyTestURL, nil)
	if err != nil {
		return download.ProxyTestResult{}, download.ErrProxyConnectionFailed
	}
	request.Close = true
	startedAt := time.Now()
	response, err := (&nethttp.Client{Transport: r}).Do(request)
	if err != nil {
		if errors.Is(err, context.DeadlineExceeded) || errors.Is(err, context.Canceled) || isTimeoutError(err) {
			return download.ProxyTestResult{}, download.ErrProxyTestTimeout
		}
		if looksLikeAuthenticationFailure(err) {
			return download.ProxyTestResult{}, download.ErrProxyAuthenticationFailed
		}
		return download.ProxyTestResult{}, download.ErrProxyConnectionFailed
	}
	defer response.Body.Close()
	if response.StatusCode == nethttp.StatusProxyAuthRequired {
		return download.ProxyTestResult{}, download.ErrProxyAuthenticationFailed
	}
	return download.ProxyTestResult{
		Mode:      settings.Mode,
		LatencyMS: max(time.Since(startedAt).Milliseconds(), 0),
	}, nil
}

func (r *ProxyRuntime) rebuildLocked() error {
	transport, err := buildTransport(r.settings, r.password)
	if err != nil {
		return err
	}
	previous := r.current.Swap(&roundTripperHolder{transport: transport})
	if previous != nil && previous.transport != nil {
		previous.transport.CloseIdleConnections()
	}
	return nil
}

func buildTransport(settings download.ProxySettings, password string) (*nethttp.Transport, error) {
	transport := nethttp.DefaultTransport.(*nethttp.Transport).Clone()
	connectTimeout := time.Duration(settings.ConnectTimeoutSeconds) * time.Second
	transport.DialContext = (&net.Dialer{
		Timeout:   connectTimeout,
		KeepAlive: 30 * time.Second,
	}).DialContext
	transport.ResponseHeaderTimeout = time.Duration(settings.ResponseHeaderTimeoutSeconds) * time.Second
	transport.TLSHandshakeTimeout = connectTimeout
	transport.ForceAttemptHTTP2 = true

	switch settings.Mode {
	case download.ProxyModeDirect:
		transport.Proxy = nil
	case download.ProxyModeSystem:
		transport.Proxy = nethttp.ProxyFromEnvironment
	case download.ProxyModeHTTP:
		proxyURL := &url.URL{
			Scheme: "http",
			Host:   net.JoinHostPort(settings.Host, fmt.Sprintf("%d", settings.Port)),
		}
		if settings.Username != "" || password != "" {
			proxyURL.User = url.UserPassword(settings.Username, password)
		}
		transport.Proxy = nethttp.ProxyURL(proxyURL)
	case download.ProxyModeSOCKS5:
		var authentication *proxy.Auth
		if settings.Username != "" || password != "" {
			authentication = &proxy.Auth{User: settings.Username, Password: password}
		}
		dialer, err := proxy.SOCKS5(
			"tcp",
			net.JoinHostPort(settings.Host, fmt.Sprintf("%d", settings.Port)),
			authentication,
			&net.Dialer{Timeout: connectTimeout, KeepAlive: 30 * time.Second},
		)
		if err != nil {
			return nil, fmt.Errorf("create SOCKS5 dialer: %w", err)
		}
		transport.Proxy = nil
		transport.DialContext = func(ctx context.Context, network, address string) (net.Conn, error) {
			if contextDialer, ok := dialer.(proxy.ContextDialer); ok {
				return contextDialer.DialContext(ctx, network, address)
			}
			return dialer.Dial(network, address)
		}
	default:
		return nil, download.ErrInvalidProxySettings
	}
	return transport, nil
}

func isTimeoutError(err error) bool {
	var networkError net.Error
	return errors.As(err, &networkError) && networkError.Timeout()
}

func looksLikeAuthenticationFailure(err error) bool {
	message := strings.ToLower(err.Error())
	return strings.Contains(message, "authentication failed") ||
		strings.Contains(message, "authentication required") ||
		strings.Contains(message, "proxyconnect tcp: http status 407")
}

var _ nethttp.RoundTripper = (*ProxyRuntime)(nil)
var _ download.ProxyService = (*ProxyRuntime)(nil)
