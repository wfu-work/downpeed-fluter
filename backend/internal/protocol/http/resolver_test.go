package httpprotocol

import (
	"context"
	"errors"
	nethttp "net/http"
	"net/http/httptest"
	"testing"

	"github.com/wfu-work/downpeed-fluter/backend/internal/download"
)

func TestResolveUsesCompleteHeadMetadata(t *testing.T) {
	getRequests := 0
	server := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, r *nethttp.Request) {
		if r.Method == nethttp.MethodGet {
			getRequests++
		}
		w.Header().Set("Content-Length", "2048")
		w.Header().Set("Content-Type", "application/octet-stream")
		w.Header().Set("Accept-Ranges", "bytes")
		w.Header().Set("ETag", `"release-v1"`)
		w.Header().Set("Last-Modified", "Tue, 11 Aug 2026 01:02:03 GMT")
	}))
	defer server.Close()

	resolution, err := NewResolver(server.Client()).Resolve(context.Background(), download.ResolveRequest{
		URL: server.URL + "/releases/downpeed.zip",
	})
	if err != nil {
		t.Fatalf("Resolve() error = %v", err)
	}
	if resolution.FileName != "downpeed.zip" {
		t.Fatalf("FileName = %q, want downpeed.zip", resolution.FileName)
	}
	if resolution.Size != 2048 {
		t.Fatalf("Size = %d, want 2048", resolution.Size)
	}
	if !resolution.AcceptRanges {
		t.Fatal("AcceptRanges = false, want true")
	}
	if resolution.ETag != `"release-v1"` || resolution.LastModified != "Tue, 11 Aug 2026 01:02:03 GMT" {
		t.Fatalf("validator = ETag %q, Last-Modified %q", resolution.ETag, resolution.LastModified)
	}
	if getRequests != 0 {
		t.Fatalf("GET requests = %d, want 0", getRequests)
	}
}

func TestResolveRejectsValidatorChangeBetweenHeadAndRangeProbe(t *testing.T) {
	server := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, r *nethttp.Request) {
		if r.Method == nethttp.MethodHead {
			w.Header().Set("Content-Length", "4096")
			w.Header().Set("ETag", `"release-v1"`)
			return
		}
		w.Header().Set("ETag", `"release-v2"`)
		w.Header().Set("Content-Range", "bytes 0-0/4096")
		w.WriteHeader(nethttp.StatusPartialContent)
		_, _ = w.Write([]byte("x"))
	}))
	defer server.Close()

	_, err := NewResolver(server.Client()).Resolve(context.Background(), download.ResolveRequest{URL: server.URL})
	if !errors.Is(err, download.ErrRemoteChanged) {
		t.Fatalf("error = %v, want ErrRemoteChanged", err)
	}
}

func TestResolveUsesRangeProbeWhenHeadOmitsAUsableValidator(t *testing.T) {
	getRequests := 0
	server := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, r *nethttp.Request) {
		if r.Method == nethttp.MethodHead {
			w.Header().Set("Content-Length", "2048")
			w.Header().Set("Accept-Ranges", "bytes")
			return
		}
		getRequests++
		w.Header().Set("ETag", `"release-v1"`)
		w.Header().Set("Content-Range", "bytes 0-0/2048")
		w.WriteHeader(nethttp.StatusPartialContent)
		_, _ = w.Write([]byte("x"))
	}))
	defer server.Close()

	resolution, err := NewResolver(server.Client()).Resolve(context.Background(), download.ResolveRequest{URL: server.URL})
	if err != nil {
		t.Fatal(err)
	}
	if getRequests != 1 || resolution.ETag != `"release-v1"` || !resolution.AcceptRanges {
		t.Fatalf("requests = %d, resolution = %#v", getRequests, resolution)
	}
}

func TestResolveFollowsRedirectAndUsesRFCFilename(t *testing.T) {
	server := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, r *nethttp.Request) {
		if r.URL.Path == "/start" {
			nethttp.Redirect(w, r, "/assets/final.bin", nethttp.StatusTemporaryRedirect)
			return
		}
		w.Header().Set("Content-Length", "512")
		w.Header().Set("Accept-Ranges", "bytes")
		w.Header().Set("Content-Disposition", "attachment; filename*=UTF-8''Downpeed%20%E4%B8%AD%E6%96%87.zip")
	}))
	defer server.Close()

	resolution, err := NewResolver(server.Client()).Resolve(context.Background(), download.ResolveRequest{
		URL: server.URL + "/start",
	})
	if err != nil {
		t.Fatalf("Resolve() error = %v", err)
	}
	if resolution.FinalURL != server.URL+"/assets/final.bin" {
		t.Fatalf("FinalURL = %q", resolution.FinalURL)
	}
	if resolution.FileName != "Downpeed 中文.zip" {
		t.Fatalf("FileName = %q", resolution.FileName)
	}
}

func TestResolveProbesRangeWhenHeadIsUncertain(t *testing.T) {
	rangeHeader := ""
	server := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, r *nethttp.Request) {
		if r.Method == nethttp.MethodHead {
			w.Header().Set("Content-Length", "4096")
			return
		}
		rangeHeader = r.Header.Get("Range")
		w.Header().Set("Content-Range", "bytes 0-0/4096")
		w.Header().Set("Content-Length", "1")
		w.WriteHeader(nethttp.StatusPartialContent)
		_, _ = w.Write([]byte("x"))
	}))
	defer server.Close()

	resolution, err := NewResolver(server.Client()).Resolve(context.Background(), download.ResolveRequest{
		URL:     server.URL + "/payload.bin",
		Headers: map[string]string{"Range": "bytes=20-30"},
	})
	if err != nil {
		t.Fatalf("Resolve() error = %v", err)
	}
	if rangeHeader != "bytes=0-0" {
		t.Fatalf("Range = %q, want bytes=0-0", rangeHeader)
	}
	if resolution.Size != 4096 || !resolution.AcceptRanges {
		t.Fatalf("resolution = %#v", resolution)
	}
}

func TestResolveFallsBackWhenHeadIsRejected(t *testing.T) {
	server := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, r *nethttp.Request) {
		if r.Method == nethttp.MethodHead {
			w.WriteHeader(nethttp.StatusMethodNotAllowed)
			return
		}
		w.Header().Set("Content-Disposition", `attachment; filename="archive.tar"`)
		w.Header().Set("Content-Range", "bytes 0-0/99")
		w.WriteHeader(nethttp.StatusPartialContent)
	}))
	defer server.Close()

	resolution, err := NewResolver(server.Client()).Resolve(context.Background(), download.ResolveRequest{
		URL: server.URL,
	})
	if err != nil {
		t.Fatalf("Resolve() error = %v", err)
	}
	if resolution.FileName != "archive.tar" || resolution.Size != 99 || !resolution.AcceptRanges {
		t.Fatalf("resolution = %#v", resolution)
	}
}

func TestResolveRejectsUnsupportedScheme(t *testing.T) {
	_, err := NewResolver(nil).Resolve(context.Background(), download.ResolveRequest{URL: "ftp://example.com/file"})
	if !errors.Is(err, download.ErrUnsupportedScheme) {
		t.Fatalf("error = %v, want ErrUnsupportedScheme", err)
	}
}

func TestResolveUsesSafeDefaultFilename(t *testing.T) {
	server := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, _ *nethttp.Request) {
		w.Header().Set("Content-Length", "0")
		w.Header().Set("Accept-Ranges", "bytes")
	}))
	defer server.Close()

	resolution, err := NewResolver(server.Client()).Resolve(context.Background(), download.ResolveRequest{URL: server.URL})
	if err != nil {
		t.Fatalf("Resolve() error = %v", err)
	}
	if resolution.FileName != "download" {
		t.Fatalf("FileName = %q, want download", resolution.FileName)
	}
}

func TestResolveDoesNotTrustMalformedContentRange(t *testing.T) {
	server := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, r *nethttp.Request) {
		if r.Method == nethttp.MethodHead {
			w.WriteHeader(nethttp.StatusMethodNotAllowed)
			return
		}
		w.Header().Set("Content-Range", "bytes nope")
		w.WriteHeader(nethttp.StatusPartialContent)
	}))
	defer server.Close()

	resolution, err := NewResolver(server.Client()).Resolve(context.Background(), download.ResolveRequest{
		URL: server.URL + "/file.bin",
	})
	if err != nil {
		t.Fatalf("Resolve() error = %v", err)
	}
	if resolution.AcceptRanges || resolution.Size != -1 {
		t.Fatalf("resolution = %#v, want unknown non-resumable source", resolution)
	}
}

func TestSanitizeFileNameIsPortable(t *testing.T) {
	tests := map[string]string{
		`folder/name?.zip`: "folder_name_.zip",
		"report\x00.txt":   "report_.txt",
		"CON.txt":          "_CON.txt",
		"LPT9":             "_LPT9",
	}
	for input, want := range tests {
		if got := download.SafeFileName(input); got != want {
			t.Errorf("SafeFileName(%q) = %q, want %q", input, got, want)
		}
	}
}
