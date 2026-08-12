package bt

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/netip"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/anacrolix/torrent"
	"github.com/anacrolix/torrent/iplist"
	"github.com/anacrolix/torrent/metainfo"

	"github.com/wfu-work/downpeed-fluter/backend/internal/download"
)

var (
	ErrRestrictedAddress      = errors.New("BT address is outside the allowed public network range")
	ErrNetworkFeatureDisabled = errors.New("BT network feature is disabled by the current security policy")
	ErrInvalidDataDirectory   = errors.New("BT data directory is invalid")
)

const (
	maxEstablishedPeersPerTorrent = 80
	maxHalfOpenPeersPerTorrent    = 20
	maxTotalHalfOpenPeers         = 60
	maxUnverifiedBytes            = int64(64 << 20)
	fallbackUploadBytesPerSecond  = 64 << 10
	fallbackUploadBurstBytes      = 32 << 10
)

var restrictedIPv4Prefixes = []netip.Prefix{
	netip.MustParsePrefix("0.0.0.0/8"),
	netip.MustParsePrefix("10.0.0.0/8"),
	netip.MustParsePrefix("100.64.0.0/10"),
	netip.MustParsePrefix("127.0.0.0/8"),
	netip.MustParsePrefix("169.254.0.0/16"),
	netip.MustParsePrefix("172.16.0.0/12"),
	netip.MustParsePrefix("192.0.0.0/24"),
	netip.MustParsePrefix("192.0.2.0/24"),
	netip.MustParsePrefix("192.168.0.0/16"),
	netip.MustParsePrefix("198.18.0.0/15"),
	netip.MustParsePrefix("198.51.100.0/24"),
	netip.MustParsePrefix("203.0.113.0/24"),
	netip.MustParsePrefix("224.0.0.0/4"),
	netip.MustParsePrefix("240.0.0.0/4"),
}

// SecureClientConfig constructs the only supported anacrolix client baseline.
// Discovery and upload features stay closed until their threat-model gates are
// implemented independently.
func SecureClientConfig(dataDirectory string, policies ...download.BTPolicySettings) (*torrent.ClientConfig, error) {
	directory := filepath.Clean(strings.TrimSpace(dataDirectory))
	if directory == "." || !filepath.IsAbs(directory) {
		return nil, ErrInvalidDataDirectory
	}

	dialer := newRestrictedDialer()
	policy := download.DefaultBTPolicySettings()
	if len(policies) > 0 {
		candidate := policies[0]
		if candidate.MaxPeerConnections < download.MinBTPeerConnections || candidate.MaxPeerConnections > download.MaxBTPeerConnections || !candidate.ExplicitPeersOnly || candidate.TrackersEnabled || candidate.DHTEnabled || candidate.PEXEnabled || candidate.WebSeedsEnabled || candidate.InboundEnabled || candidate.IPv6Enabled || candidate.UploadEnabled || candidate.SeedingEnabled {
			return nil, ErrNetworkFeatureDisabled
		}
		policy = candidate
	}
	config := torrent.NewDefaultClientConfig()
	config.DataDir = directory
	config.ListenHost = func(string) string { return "127.0.0.1" }
	config.ListenPort = 0
	config.NoDefaultPortForwarding = true
	config.DisableTrackers = true
	config.NoDHT = true
	config.PeriodicallyAnnounceTorrentsToDht = false
	config.DisablePEX = true
	config.DisableIPv6 = true
	config.DisableUTP = true
	config.DisableWebtorrent = true
	config.DisableWebseeds = true
	config.NoUpload = true
	config.DisableAggressiveUpload = true
	config.Seed = false
	config.AcceptPeerConnections = false
	config.AlwaysWantConns = false
	config.DisableAcceptRateLimiting = false
	config.DropDuplicatePeerIds = true
	config.EstablishedConnsPerTorrent = min(policy.MaxPeerConnections, maxEstablishedPeersPerTorrent)
	config.HalfOpenConnsPerTorrent = min(policy.MaxPeerConnections, maxHalfOpenPeersPerTorrent)
	config.TotalHalfOpenConns = maxTotalHalfOpenPeers
	config.MaxUnverifiedBytes = maxUnverifiedBytes
	config.IPBlocklist = RestrictedIPBlocklist{}
	config.TrackerDialContext = dialer.DialContext
	config.HTTPDialContext = dialer.DialContext
	config.TrackerListenPacket = rejectPacketListener
	config.WebTransport = disabledRoundTripper{}
	config.MetainfoSourcesClient = &http.Client{
		Transport: disabledRoundTripper{},
		Timeout:   time.Second,
	}
	config.MetainfoSourcesMerger = func(*torrent.Torrent, *metainfo.MetaInfo) error {
		return ErrNetworkFeatureDisabled
	}
	config.HttpRequestDirector = func(*http.Request) error {
		return ErrNetworkFeatureDisabled
	}
	config.UploadRateLimiter.SetLimit(fallbackUploadBytesPerSecond)
	config.UploadRateLimiter.SetBurst(fallbackUploadBurstBytes)
	return config, nil
}

// IsAllowedPublicIP applies the shared first-release Peer and HTTP address
// policy. Native IPv6 is disabled; IPv4-mapped IPv6 is classified as IPv4.
func IsAllowedPublicIP(ip net.IP) bool {
	address, ok := netip.AddrFromSlice(ip)
	if !ok {
		return false
	}
	address = address.Unmap()
	if !address.Is4() {
		return false
	}
	for _, prefix := range restrictedIPv4Prefixes {
		if prefix.Contains(address) {
			return false
		}
	}
	return address.IsGlobalUnicast()
}

type RestrictedIPBlocklist struct{}

func (RestrictedIPBlocklist) Lookup(ip net.IP) (iplist.Range, bool) {
	if IsAllowedPublicIP(ip) {
		return iplist.Range{}, false
	}
	copyIP := append(net.IP(nil), ip...)
	return iplist.Range{
		First:       copyIP,
		Last:        append(net.IP(nil), copyIP...),
		Description: "downpeed restricted address",
	}, true
}

func (RestrictedIPBlocklist) NumRanges() int {
	return len(restrictedIPv4Prefixes) + 1
}

type lookupNetIPFunc func(context.Context, string, string) ([]netip.Addr, error)
type dialContextFunc func(context.Context, string, string) (net.Conn, error)

type restrictedDialer struct {
	lookupNetIP lookupNetIPFunc
	dialContext dialContextFunc
}

func newRestrictedDialer() restrictedDialer {
	dialer := &net.Dialer{Timeout: 10 * time.Second, KeepAlive: 30 * time.Second}
	return restrictedDialer{
		lookupNetIP: net.DefaultResolver.LookupNetIP,
		dialContext: dialer.DialContext,
	}
}

func (d restrictedDialer) DialContext(ctx context.Context, network, address string) (net.Conn, error) {
	if network != "tcp" && network != "tcp4" {
		return nil, ErrNetworkFeatureDisabled
	}
	host, portText, err := net.SplitHostPort(address)
	if err != nil || strings.Contains(host, "%") {
		return nil, ErrRestrictedAddress
	}
	port, err := strconv.ParseUint(portText, 10, 16)
	if err != nil || port == 0 {
		return nil, ErrRestrictedAddress
	}

	addresses, err := d.resolveIPv4(ctx, host)
	if err != nil {
		return nil, err
	}
	var lastError error
	allowed := false
	for _, candidate := range addresses {
		if !IsAllowedPublicIP(net.IP(candidate.AsSlice())) {
			continue
		}
		allowed = true
		connection, dialErr := d.dialContext(
			ctx,
			"tcp4",
			net.JoinHostPort(candidate.String(), strconv.FormatUint(port, 10)),
		)
		if dialErr == nil {
			return connection, nil
		}
		lastError = dialErr
	}
	if !allowed {
		return nil, ErrRestrictedAddress
	}
	if lastError != nil {
		return nil, fmt.Errorf("BT public endpoint connection failed: %w", lastError)
	}
	return nil, ErrRestrictedAddress
}

func (d restrictedDialer) resolveIPv4(ctx context.Context, host string) ([]netip.Addr, error) {
	if literal, err := netip.ParseAddr(host); err == nil {
		literal = literal.Unmap()
		if !literal.Is4() {
			return nil, ErrRestrictedAddress
		}
		return []netip.Addr{literal}, nil
	}
	addresses, err := d.lookupNetIP(ctx, "ip4", host)
	if err != nil {
		return nil, errors.New("BT endpoint name could not be resolved")
	}
	return addresses, nil
}

func rejectPacketListener(string, string) (net.PacketConn, error) {
	return nil, ErrNetworkFeatureDisabled
}

type disabledRoundTripper struct{}

func (disabledRoundTripper) RoundTrip(*http.Request) (*http.Response, error) {
	return nil, ErrNetworkFeatureDisabled
}

var _ iplist.Ranger = RestrictedIPBlocklist{}
