package bt

import (
	"bytes"
	"context"
	"errors"
	"net"
	"net/http"
	"net/netip"
	"path/filepath"
	"testing"

	"github.com/anacrolix/torrent"
	"github.com/anacrolix/torrent/bencode"
	"github.com/anacrolix/torrent/metainfo"

	"github.com/wfu-work/downpeed-fluter/backend/internal/download"
)

func TestSecureClientConfigOverridesUnsafeDefaults(t *testing.T) {
	dataDirectory := filepath.Join(t.TempDir(), "bt-data")
	config, err := SecureClientConfig(dataDirectory)
	if err != nil {
		t.Fatal(err)
	}
	if config.DataDir != dataDirectory || config.ListenPort != 0 || config.ListenHost("tcp4") != "127.0.0.1" {
		t.Fatalf("listener configuration = data %q, host %q, port %d", config.DataDir, config.ListenHost("tcp4"), config.ListenPort)
	}
	if !config.NoDefaultPortForwarding || !config.DisableTrackers || !config.NoDHT || !config.DisablePEX || !config.DisableIPv6 || !config.DisableUTP {
		t.Fatalf("discovery configuration is not closed: %#v", config)
	}
	if !config.DisableWebtorrent || !config.DisableWebseeds || !config.NoUpload || !config.DisableAggressiveUpload || config.Seed {
		t.Fatalf("upload or alternate transport is not closed: %#v", config)
	}
	if config.AcceptPeerConnections || config.AlwaysWantConns || config.DisableAcceptRateLimiting {
		t.Fatalf("inbound connection policy is unsafe: %#v", config)
	}
	if config.EstablishedConnsPerTorrent > maxEstablishedPeersPerTorrent ||
		config.HalfOpenConnsPerTorrent > maxHalfOpenPeersPerTorrent ||
		config.TotalHalfOpenConns > maxTotalHalfOpenPeers ||
		config.MaxUnverifiedBytes > maxUnverifiedBytes {
		t.Fatalf("resource limits exceed policy: %#v", config)
	}
	if config.IPBlocklist == nil || config.TrackerDialContext == nil || config.HTTPDialContext == nil || config.TrackerListenPacket == nil {
		t.Fatal("network filters were not installed")
	}
	if config.UploadRateLimiter == nil || config.UploadRateLimiter.Limit() <= 0 {
		t.Fatal("defense-in-depth upload limiter was not installed")
	}
	request, requestErr := http.NewRequest(http.MethodGet, "https://example.com/source.torrent", nil)
	if requestErr != nil {
		t.Fatal(requestErr)
	}
	if _, err = config.WebTransport.RoundTrip(request); !errors.Is(err, ErrNetworkFeatureDisabled) {
		t.Fatalf("WebTransport error = %v", err)
	}
	if _, err = config.TrackerListenPacket("udp4", ":0"); !errors.Is(err, ErrNetworkFeatureDisabled) {
		t.Fatalf("TrackerListenPacket error = %v", err)
	}
}

func TestSecureClientConfigRejectsRelativeDataDirectory(t *testing.T) {
	if _, err := SecureClientConfig("relative/data"); !errors.Is(err, ErrInvalidDataDirectory) {
		t.Fatalf("SecureClientConfig() error = %v", err)
	}
}

func TestSecureClientConfigAppliesRestrictedPeerBudget(t *testing.T) {
	policy := download.DefaultBTPolicySettings()
	policy.MaxPeerConnections = 12
	config, err := SecureClientConfig(filepath.Join(t.TempDir(), "bt-data"), policy)
	if err != nil {
		t.Fatal(err)
	}
	if config.EstablishedConnsPerTorrent != 12 || config.HalfOpenConnsPerTorrent != 12 {
		t.Fatalf("peer limits = established %d, half-open %d", config.EstablishedConnsPerTorrent, config.HalfOpenConnsPerTorrent)
	}
	policy.DHTEnabled = true
	if _, err = SecureClientConfig(filepath.Join(t.TempDir(), "unsafe"), policy); !errors.Is(err, ErrNetworkFeatureDisabled) {
		t.Fatalf("unsafe policy error = %v", err)
	}
}

func TestRestrictedAddressPolicy(t *testing.T) {
	tests := map[string]bool{
		"8.8.8.8":              true,
		"1.1.1.1":              true,
		"127.0.0.1":            false,
		"10.0.0.1":             false,
		"100.64.0.1":           false,
		"169.254.10.20":        false,
		"172.20.1.1":           false,
		"192.168.1.1":          false,
		"192.0.2.20":           false,
		"198.19.0.1":           false,
		"198.51.100.1":         false,
		"203.0.113.1":          false,
		"224.0.0.1":            false,
		"255.255.255.255":      false,
		"::1":                  false,
		"2001:4860:4860::8888": false,
		"::ffff:127.0.0.1":     false,
		"::ffff:8.8.8.8":       true,
	}
	blocklist := RestrictedIPBlocklist{}
	for value, allowed := range tests {
		t.Run(value, func(t *testing.T) {
			ip := net.ParseIP(value)
			if got := IsAllowedPublicIP(ip); got != allowed {
				t.Fatalf("IsAllowedPublicIP(%q) = %v, want %v", value, got, allowed)
			}
			_, blocked := blocklist.Lookup(ip)
			if blocked == allowed {
				t.Fatalf("blocklist.Lookup(%q) blocked = %v", value, blocked)
			}
		})
	}
}

func TestRestrictedDialerFiltersEveryDNSResultBeforeDialing(t *testing.T) {
	dialCalled := false
	dialer := restrictedDialer{
		lookupNetIP: func(context.Context, string, string) ([]netip.Addr, error) {
			return []netip.Addr{
				netip.MustParseAddr("127.0.0.1"),
				netip.MustParseAddr("192.168.1.8"),
			}, nil
		},
		dialContext: func(context.Context, string, string) (net.Conn, error) {
			dialCalled = true
			return nil, errors.New("unexpected dial")
		},
	}
	if _, err := dialer.DialContext(context.Background(), "tcp", "tracker.invalid:443"); !errors.Is(err, ErrRestrictedAddress) {
		t.Fatalf("DialContext() error = %v", err)
	}
	if dialCalled {
		t.Fatal("restricted DNS result reached the socket dialer")
	}
}

func TestRestrictedDialerPinsPublicDNSResult(t *testing.T) {
	var dialedAddress string
	dialer := restrictedDialer{
		lookupNetIP: func(context.Context, string, string) ([]netip.Addr, error) {
			return []netip.Addr{
				netip.MustParseAddr("10.0.0.1"),
				netip.MustParseAddr("8.8.8.8"),
			}, nil
		},
		dialContext: func(_ context.Context, network, address string) (net.Conn, error) {
			if network != "tcp4" {
				t.Fatalf("network = %q", network)
			}
			dialedAddress = address
			return nil, errors.New("stop after address assertion")
		},
	}
	if _, err := dialer.DialContext(context.Background(), "tcp", "tracker.invalid:443"); err == nil {
		t.Fatal("DialContext() error = nil")
	}
	if dialedAddress != "8.8.8.8:443" {
		t.Fatalf("dialed address = %q", dialedAddress)
	}
}

func TestRestrictedSpecsRemoveAutomaticNetworkSources(t *testing.T) {
	magnet, err := RestrictedMagnetSpec(
		context.Background(),
		"magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&tr=https%3A%2F%2Ftracker.example%2Fannounce&ws=https%3A%2F%2Fseed.example%2Ffile&xs=https%3A%2F%2Fsource.example%2Ffile.torrent&x.pe=8.8.8.8%3A6881",
	)
	if err != nil {
		t.Fatal(err)
	}
	assertRestrictedSpec(t, magnet)

	info := metainfo.Info{
		PieceLength: 16 * 1024,
		Pieces:      bytes.Repeat([]byte{1}, 20),
		Name:        "archive.bin",
		Length:      8,
	}
	infoBytes, err := bencode.Marshal(info)
	if err != nil {
		t.Fatal(err)
	}
	metadata := metainfo.MetaInfo{
		Announce:  "https://tracker.example/announce",
		UrlList:   []string{"https://seed.example/archive.bin"},
		Nodes:     []metainfo.Node{"dht.example:6881"},
		InfoBytes: infoBytes,
	}
	var encoded bytes.Buffer
	if err = bencode.NewEncoder(&encoded).Encode(metadata); err != nil {
		t.Fatal(err)
	}
	torrentSpec, err := RestrictedTorrentSpec(context.Background(), encoded.Bytes())
	if err != nil {
		t.Fatal(err)
	}
	assertRestrictedSpec(t, torrentSpec)
}

func assertRestrictedSpec(t *testing.T, spec *torrent.TorrentSpec) {
	t.Helper()
	if len(spec.Trackers) != 0 || len(spec.Webseeds) != 0 || len(spec.DhtNodes) != 0 || len(spec.PeerAddrs) != 0 || len(spec.Sources) != 0 {
		t.Fatalf("automatic network sources remain in spec: %#v", spec)
	}
	if !spec.DisallowDataUpload || spec.DisableInitialPieceCheck {
		t.Fatalf("torrent integrity/upload policy is unsafe: %#v", spec.AddTorrentOpts)
	}
}
