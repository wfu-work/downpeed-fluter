package enginehost

import (
	"encoding/json"
	"net"
	"net/http"
	"path/filepath"
	"testing"
	"time"
)

func TestHostStartsWaitsForHTTPAndStopsIdempotently(t *testing.T) {
	host := New()
	configJSON := testConfigJSON(t, "127.0.0.1:0")

	if err := host.Start(configJSON); err != nil {
		t.Fatal(err)
	}
	if host.State() != StateRunning {
		t.Fatalf("State = %v, want %v", host.State(), StateRunning)
	}
	if err := host.Start(configJSON); err != nil {
		t.Fatalf("second Start() error = %v", err)
	}

	client := &http.Client{Timeout: time.Second}
	response, err := client.Get("http://" + host.Address() + "/api/v1/health")
	if err != nil {
		t.Fatal(err)
	}
	_ = response.Body.Close()
	if response.StatusCode != http.StatusOK {
		t.Fatalf("health status = %d", response.StatusCode)
	}

	if err = host.Stop(); err != nil {
		t.Fatal(err)
	}
	if err = host.Stop(); err != nil {
		t.Fatalf("second Stop() error = %v", err)
	}
	if host.State() != StateStopped {
		t.Fatalf("State = %v, want %v", host.State(), StateStopped)
	}
}

func TestHostRejectsRemoteAndUnknownConfiguration(t *testing.T) {
	host := New()
	for _, value := range []string{
		`{"address":"0.0.0.0:17680"}`,
		`{"allowRemote":true}`,
		`{"address":"127.0.0.1:17680"} {}`,
	} {
		if err := host.Start(value); err == nil {
			t.Fatalf("Start(%q) succeeded", value)
		}
		if host.State() != StateStopped {
			t.Fatalf("State = %v, want stopped", host.State())
		}
	}
}

func TestHostReportsOccupiedAddressWithoutLeakingIt(t *testing.T) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()

	host := New()
	if err = host.Start(testConfigJSON(t, listener.Addr().String())); err == nil {
		t.Fatal("Start() succeeded on an occupied address")
	}
	if got := host.LastError(); got != "The local Downpeed engine address is already in use or unavailable." {
		t.Fatalf("LastError() = %q", got)
	}
}

func testConfigJSON(t *testing.T, address string) string {
	t.Helper()
	data, err := json.Marshal(map[string]any{
		"address":                  address,
		"dataDir":                  t.TempDir(),
		"defaultDownloadDirectory": filepath.Join(t.TempDir(), "Downloads"),
	})
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}
