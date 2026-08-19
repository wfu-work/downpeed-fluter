package httpprotocol

import (
	"bufio"
	"io"
	"net"
	nethttp "net/http"
	"net/http/httptest"
	"net/url"
	"sync/atomic"
	"testing"

	"github.com/wfu-work/downpeed-fluter/backend/internal/download"
)

func TestProxyRuntimeSwitchesNewRequestsWithoutInterruptingActiveResponse(t *testing.T) {
	release := make(chan struct{})
	target := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, _ *nethttp.Request) {
		flusher, ok := w.(nethttp.Flusher)
		if !ok {
			t.Fatal("response writer cannot flush")
		}
		_, _ = io.WriteString(w, "before\n")
		flusher.Flush()
		<-release
		_, _ = io.WriteString(w, "after\n")
	}))
	defer target.Close()

	runtime, err := NewProxyRuntime(download.DefaultProxySettings())
	if err != nil {
		t.Fatal(err)
	}
	client := &nethttp.Client{Transport: runtime}
	response, err := client.Get(target.URL)
	if err != nil {
		t.Fatal(err)
	}
	reader := bufio.NewReader(response.Body)
	first, err := reader.ReadString('\n')
	if err != nil || first != "before\n" {
		t.Fatalf("first chunk = %q, error = %v", first, err)
	}

	proxy := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, request *nethttp.Request) {
		w.Header().Set("X-Downpeed-Proxy", "used")
		_, _ = io.WriteString(w, request.URL.String())
	}))
	defer proxy.Close()
	proxyURL, _ := url.Parse(proxy.URL)
	host, port, _ := net.SplitHostPort(proxyURL.Host)
	parsedPort, _ := net.LookupPort("tcp", port)
	runtime.ApplySettings(download.ProxySettings{
		Mode:                         download.ProxyModeHTTP,
		Host:                         host,
		Port:                         parsedPort,
		ConnectTimeoutSeconds:        5,
		ResponseHeaderTimeoutSeconds: 5,
	})
	close(release)
	remainder, err := io.ReadAll(reader)
	_ = response.Body.Close()
	if err != nil || string(remainder) != "after\n" {
		t.Fatalf("active response remainder = %q, error = %v", remainder, err)
	}

	next, err := client.Get("http://download.example/file")
	if err != nil {
		t.Fatal(err)
	}
	defer next.Body.Close()
	if next.Header.Get("X-Downpeed-Proxy") != "used" {
		t.Fatal("new request did not use updated proxy")
	}
}

func TestProxyRuntimeSendsHTTPProxyCredentialsWithoutExposingThem(t *testing.T) {
	var authorization atomic.Value
	proxyServer := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, request *nethttp.Request) {
		authorization.Store(request.Header.Get("Proxy-Authorization"))
		w.WriteHeader(nethttp.StatusNoContent)
	}))
	defer proxyServer.Close()
	proxyURL, _ := url.Parse(proxyServer.URL)
	host, port, _ := net.SplitHostPort(proxyURL.Host)
	parsedPort, _ := net.LookupPort("tcp", port)
	runtime, err := NewProxyRuntime(download.ProxySettings{
		Mode:                         download.ProxyModeHTTP,
		Host:                         host,
		Port:                         parsedPort,
		Username:                     "downpeed-user",
		ConnectTimeoutSeconds:        5,
		ResponseHeaderTimeoutSeconds: 5,
	})
	if err != nil {
		t.Fatal(err)
	}
	if err = runtime.SetPassword("proxy-secret"); err != nil {
		t.Fatal(err)
	}
	response, err := (&nethttp.Client{Transport: runtime}).Get("http://download.example/file")
	if err != nil {
		t.Fatal(err)
	}
	_ = response.Body.Close()
	if value, _ := authorization.Load().(string); value == "" {
		t.Fatal("proxy authorization header was not sent")
	}
	if runtime.settings.Username != "downpeed-user" || runtime.password != "proxy-secret" {
		t.Fatal("runtime did not retain credentials in memory")
	}
}
