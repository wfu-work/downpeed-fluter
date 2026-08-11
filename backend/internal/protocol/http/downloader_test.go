package httpprotocol

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	nethttp "net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"sort"
	"sync"
	"testing"
	"time"

	"github.com/wfu-work/downpeed-fluter/backend/internal/download"
)

func TestDownloaderTransfersOneConnectionAndReportsProgress(t *testing.T) {
	payload := bytes.Repeat([]byte("downpeed"), 32*1024)
	requests := 0
	server := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, r *nethttp.Request) {
		requests++
		if r.Method != nethttp.MethodGet {
			t.Errorf("method = %s, want GET", r.Method)
		}
		w.Header().Set("Content-Length", fmt.Sprint(len(payload)))
		_, _ = w.Write(payload)
	}))
	defer server.Close()
	destination := filepath.Join(t.TempDir(), "payload.bin")
	workPath := destination + ".downpeed"
	var lastProgress download.TransferProgress
	limiter := &countingLimiter{}

	result, err := NewDownloader(server.Client()).Download(
		context.Background(),
		download.TransferRequest{URL: server.URL + "/payload.bin", Destination: destination, WorkPath: workPath, Limiter: limiter},
		func(progress download.TransferProgress) { lastProgress = progress },
	)
	if err != nil {
		t.Fatalf("Download() error = %v", err)
	}
	written, err := os.ReadFile(destination)
	if err != nil {
		t.Fatalf("ReadFile() error = %v", err)
	}
	if !bytes.Equal(written, payload) {
		t.Fatal("downloaded file does not match payload")
	}
	if requests != 1 {
		t.Fatalf("requests = %d, want one connection", requests)
	}
	if result.Size != int64(len(payload)) || lastProgress.Downloaded != result.Size {
		t.Fatalf("result = %#v, progress = %#v", result, lastProgress)
	}
	if limiter.Total() != int64(len(payload)) {
		t.Fatalf("limited bytes = %d, want %d", limiter.Total(), len(payload))
	}
	if _, err = os.Stat(workPath); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("temporary file still exists after completion: %v", err)
	}
}

func TestDownloaderDoesNotOverwriteExistingFile(t *testing.T) {
	directory := t.TempDir()
	destination := filepath.Join(directory, "existing.bin")
	workPath := filepath.Join(directory, ".existing.bin.downpeed")
	if err := os.WriteFile(destination, []byte("keep"), 0o644); err != nil {
		t.Fatal(err)
	}

	_, err := NewDownloader(nil).Download(context.Background(), download.TransferRequest{
		URL:         "https://example.com/file.bin",
		Destination: destination,
		WorkPath:    workPath,
	}, nil)
	if !errors.Is(err, download.ErrDestinationExists) {
		t.Fatalf("error = %v, want ErrDestinationExists", err)
	}
	value, _ := os.ReadFile(destination)
	if string(value) != "keep" {
		t.Fatalf("existing file = %q", value)
	}
}

func TestDownloaderCancellationCleansIncompleteFile(t *testing.T) {
	server := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, r *nethttp.Request) {
		flusher := w.(nethttp.Flusher)
		for index := 0; index < 100; index++ {
			select {
			case <-r.Context().Done():
				return
			default:
			}
			_, _ = w.Write(bytes.Repeat([]byte("x"), 16*1024))
			flusher.Flush()
			time.Sleep(2 * time.Millisecond)
		}
	}))
	defer server.Close()
	ctx, cancel := context.WithCancel(context.Background())
	destination := filepath.Join(t.TempDir(), "partial.bin")
	workPath := destination + ".downpeed"

	_, err := NewDownloader(server.Client()).Download(ctx, download.TransferRequest{
		URL:         server.URL + "/stream",
		Destination: destination,
		WorkPath:    workPath,
	}, func(progress download.TransferProgress) {
		if progress.Downloaded > 0 {
			cancel()
		}
	})
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("error = %v, want context.Canceled", err)
	}
	if _, err = os.Stat(destination); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("final file exists after cancellation: %v", err)
	}
	if _, err = os.Stat(workPath); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("temporary file still exists after cancellation: %v", err)
	}
}

func TestDownloaderPauseKeepsIncompleteFile(t *testing.T) {
	server := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, r *nethttp.Request) {
		flusher := w.(nethttp.Flusher)
		for index := 0; index < 100; index++ {
			select {
			case <-r.Context().Done():
				return
			default:
			}
			_, _ = w.Write(bytes.Repeat([]byte("p"), 16*1024))
			flusher.Flush()
			time.Sleep(2 * time.Millisecond)
		}
	}))
	defer server.Close()
	ctx, pause := context.WithCancelCause(context.Background())
	destination := filepath.Join(t.TempDir(), "paused.bin")
	workPath := destination + ".downpeed"

	_, err := NewDownloader(server.Client()).Download(ctx, download.TransferRequest{
		URL:         server.URL + "/stream",
		Destination: destination,
		WorkPath:    workPath,
	}, func(progress download.TransferProgress) {
		if progress.Downloaded > 0 {
			pause(download.ErrTransferPaused)
		}
	})
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("error = %v, want context.Canceled", err)
	}
	if _, err = os.Stat(destination); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("final file became visible while paused: %v", err)
	}
	info, err := os.Stat(workPath)
	if err != nil || info.Size() == 0 {
		t.Fatalf("paused partial file is unavailable: info=%v err=%v", info, err)
	}
}

func TestDownloaderResumesWithRangeAndAppends(t *testing.T) {
	lastModified := "Tue, 11 Aug 2026 01:02:03 GMT"
	server := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, r *nethttp.Request) {
		if got := r.Header.Get("Range"); got != "bytes=4-" {
			t.Errorf("Range = %q, want bytes=4-", got)
		}
		if got := r.Header.Get("If-Range"); got != lastModified {
			t.Errorf("If-Range = %q, want %q", got, lastModified)
		}
		w.Header().Set("Last-Modified", lastModified)
		w.Header().Set("Content-Length", "4")
		w.Header().Set("Content-Range", "bytes 4-7/8")
		w.WriteHeader(nethttp.StatusPartialContent)
		_, _ = w.Write([]byte("peed"))
	}))
	defer server.Close()
	destination := filepath.Join(t.TempDir(), "resume.bin")
	workPath := destination + ".downpeed"
	if err := os.WriteFile(workPath, []byte("down"), 0o644); err != nil {
		t.Fatal(err)
	}
	var progress download.TransferProgress
	result, err := NewDownloader(server.Client()).Download(context.Background(), download.TransferRequest{
		URL:         server.URL + "/resume.bin",
		Destination: destination,
		WorkPath:    workPath,
		Offset:      4,
		Validator:   download.ResourceValidator{LastModified: lastModified},
	}, func(value download.TransferProgress) { progress = value })
	if err != nil {
		t.Fatal(err)
	}
	value, err := os.ReadFile(destination)
	if err != nil || !bytes.Equal(value, []byte("downpeed")) {
		t.Fatalf("resumed file = %q, error = %v", value, err)
	}
	if result.Size != 8 || progress.Downloaded != 8 || progress.Total != 8 {
		t.Fatalf("result = %#v, progress = %#v", result, progress)
	}
	if _, err = os.Stat(workPath); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("temporary file still exists after resumed completion: %v", err)
	}
}

func TestDownloaderStopsResumeWhenStrongETagChanged(t *testing.T) {
	server := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, r *nethttp.Request) {
		if got := r.Header.Get("Range"); got != "bytes=4-" {
			t.Errorf("Range = %q, want bytes=4-", got)
		}
		if got := r.Header.Get("If-Range"); got != `"release-v1"` {
			t.Errorf("If-Range = %q, want release-v1", got)
		}
		w.Header().Set("ETag", `"release-v2"`)
		w.WriteHeader(nethttp.StatusOK)
		_, _ = w.Write([]byte("changed-content"))
	}))
	defer server.Close()
	destination := filepath.Join(t.TempDir(), "changed.bin")
	workPath := destination + ".downpeed"
	if err := os.WriteFile(workPath, []byte("down"), 0o644); err != nil {
		t.Fatal(err)
	}

	_, err := NewDownloader(server.Client()).Download(context.Background(), download.TransferRequest{
		URL:         server.URL,
		Destination: destination,
		WorkPath:    workPath,
		Offset:      4,
		Validator:   download.ResourceValidator{ETag: `"release-v1"`},
	}, nil)
	if !errors.Is(err, download.ErrRemoteChanged) {
		t.Fatalf("error = %v, want ErrRemoteChanged", err)
	}
	partial, readErr := os.ReadFile(workPath)
	if readErr != nil || !bytes.Equal(partial, []byte("down")) {
		t.Fatalf("partial = %q, error = %v", partial, readErr)
	}
	if _, statErr := os.Stat(destination); !errors.Is(statErr, os.ErrNotExist) {
		t.Fatalf("changed resource was published: %v", statErr)
	}
}

func TestDownloaderUsesStrongETagForInitialRequest(t *testing.T) {
	server := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, r *nethttp.Request) {
		if got := r.Header.Get("If-Match"); got != `"release-v1"` {
			t.Errorf("If-Match = %q, want release-v1", got)
		}
		if got := r.Header.Get("If-Range"); got != "" {
			t.Errorf("unexpected If-Range = %q", got)
		}
		w.Header().Set("ETag", `"release-v1"`)
		_, _ = w.Write([]byte("safe"))
	}))
	defer server.Close()
	destination := filepath.Join(t.TempDir(), "initial.bin")

	_, err := NewDownloader(server.Client()).Download(context.Background(), download.TransferRequest{
		URL:         server.URL,
		Destination: destination,
		WorkPath:    destination + ".downpeed",
		Validator:   download.ResourceValidator{ETag: `"release-v1"`},
	}, nil)
	if err != nil {
		t.Fatal(err)
	}
	value, err := os.ReadFile(destination)
	if err != nil || !bytes.Equal(value, []byte("safe")) {
		t.Fatalf("downloaded = %q, error = %v", value, err)
	}
}

func TestDownloaderRejectsMismatchedETagWhenServerIgnoresPrecondition(t *testing.T) {
	server := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, _ *nethttp.Request) {
		w.Header().Set("ETag", `"release-v2"`)
		_, _ = w.Write([]byte("same-size-but-new"))
	}))
	defer server.Close()
	destination := filepath.Join(t.TempDir(), "mismatch.bin")
	workPath := destination + ".downpeed"

	_, err := NewDownloader(server.Client()).Download(context.Background(), download.TransferRequest{
		URL:         server.URL,
		Destination: destination,
		WorkPath:    workPath,
		Validator:   download.ResourceValidator{ETag: `"release-v1"`},
	}, nil)
	if !errors.Is(err, download.ErrRemoteChanged) {
		t.Fatalf("error = %v, want ErrRemoteChanged", err)
	}
	if _, statErr := os.Stat(destination); !errors.Is(statErr, os.ErrNotExist) {
		t.Fatalf("mismatched resource was published: %v", statErr)
	}
	if _, statErr := os.Stat(workPath); !errors.Is(statErr, os.ErrNotExist) {
		t.Fatalf("mismatched work file remains: %v", statErr)
	}
}

func TestDownloaderRejectsInvalidContentRangeWithoutCorruptingPartial(t *testing.T) {
	server := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, _ *nethttp.Request) {
		w.Header().Set("Content-Range", "bytes 0-3/8")
		w.WriteHeader(nethttp.StatusPartialContent)
		_, _ = w.Write([]byte("bad!"))
	}))
	defer server.Close()
	destination := filepath.Join(t.TempDir(), "partial.bin")
	workPath := destination + ".downpeed"
	if err := os.WriteFile(workPath, []byte("down"), 0o644); err != nil {
		t.Fatal(err)
	}
	_, err := NewDownloader(server.Client()).Download(context.Background(), download.TransferRequest{
		URL:         server.URL,
		Destination: destination,
		WorkPath:    workPath,
		Offset:      4,
	}, nil)
	if !errors.Is(err, download.ErrResumeNotSupported) {
		t.Fatalf("error = %v, want ErrResumeNotSupported", err)
	}
	value, readErr := os.ReadFile(workPath)
	if readErr != nil || !bytes.Equal(value, []byte("down")) {
		t.Fatalf("partial file = %q, error = %v", value, readErr)
	}
}

func TestDownloaderPublishesAlreadyCompletePausedFileWithoutAnotherRequest(t *testing.T) {
	requests := 0
	server := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, _ *nethttp.Request) {
		requests++
		w.WriteHeader(nethttp.StatusInternalServerError)
	}))
	defer server.Close()
	destination := filepath.Join(t.TempDir(), "complete.bin")
	workPath := destination + ".downpeed"
	if err := os.WriteFile(workPath, []byte("done"), 0o644); err != nil {
		t.Fatal(err)
	}

	result, err := NewDownloader(server.Client()).Download(context.Background(), download.TransferRequest{
		URL:          server.URL,
		Destination:  destination,
		WorkPath:     workPath,
		Offset:       4,
		ExpectedSize: 4,
	}, nil)
	if err != nil {
		t.Fatal(err)
	}
	if requests != 0 || result.Size != 4 {
		t.Fatalf("requests = %d, result = %#v", requests, result)
	}
	value, err := os.ReadFile(destination)
	if err != nil || !bytes.Equal(value, []byte("done")) {
		t.Fatalf("completed file = %q, error = %v", value, err)
	}
}

func TestDownloaderDoesNotOverwriteDestinationCreatedBeforePublish(t *testing.T) {
	payload := bytes.Repeat([]byte("safe"), 1024)
	server := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, _ *nethttp.Request) {
		w.Header().Set("Content-Length", fmt.Sprint(len(payload)))
		_, _ = w.Write(payload)
	}))
	defer server.Close()
	destination := filepath.Join(t.TempDir(), "collision.bin")
	workPath := destination + ".downpeed"
	createdConflict := false

	_, err := NewDownloader(server.Client()).Download(context.Background(), download.TransferRequest{
		URL:         server.URL,
		Destination: destination,
		WorkPath:    workPath,
	}, func(progress download.TransferProgress) {
		if progress.Downloaded > 0 && !createdConflict {
			createdConflict = true
			if writeErr := os.WriteFile(destination, []byte("external"), 0o644); writeErr != nil {
				t.Errorf("create destination conflict: %v", writeErr)
			}
		}
	})
	if !errors.Is(err, download.ErrDestinationExists) {
		t.Fatalf("error = %v, want ErrDestinationExists", err)
	}
	value, readErr := os.ReadFile(destination)
	if readErr != nil || !bytes.Equal(value, []byte("external")) {
		t.Fatalf("destination = %q, error = %v", value, readErr)
	}
	if _, statErr := os.Stat(workPath); !errors.Is(statErr, os.ErrNotExist) {
		t.Fatalf("temporary file still exists after publish conflict: %v", statErr)
	}
}

func TestDownloaderRejectsHTTPErrorWithoutLeavingFile(t *testing.T) {
	server := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, _ *nethttp.Request) {
		w.WriteHeader(nethttp.StatusForbidden)
	}))
	defer server.Close()
	destination := filepath.Join(t.TempDir(), "forbidden.bin")
	workPath := destination + ".downpeed"

	_, err := NewDownloader(server.Client()).Download(context.Background(), download.TransferRequest{
		URL:         server.URL,
		Destination: destination,
		WorkPath:    workPath,
	}, nil)
	if !errors.Is(err, download.ErrRemoteRejected) {
		t.Fatalf("error = %v, want ErrRemoteRejected", err)
	}
	if _, statErr := os.Stat(destination); !errors.Is(statErr, os.ErrNotExist) {
		t.Fatalf("file still exists: %v", statErr)
	}
	if _, statErr := os.Stat(workPath); !errors.Is(statErr, os.ErrNotExist) {
		t.Fatalf("temporary file still exists: %v", statErr)
	}
}

func TestDownloaderUsesFourValidatedSegments(t *testing.T) {
	payload := bytes.Repeat([]byte("segment-data"), 96*1024)
	var requestMu sync.Mutex
	ranges := make([]string, 0, segmentedConnectionCount)
	server := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, r *nethttp.Request) {
		start, end, ok := readRequestedRange(r.Header.Get("Range"))
		if !ok || start < 0 || end < start || end >= int64(len(payload)) {
			t.Errorf("invalid Range = %q", r.Header.Get("Range"))
			w.WriteHeader(nethttp.StatusRequestedRangeNotSatisfiable)
			return
		}
		requestMu.Lock()
		ranges = append(ranges, r.Header.Get("Range"))
		requestMu.Unlock()
		w.Header().Set("Content-Range", fmt.Sprintf("bytes %d-%d/%d", start, end, len(payload)))
		w.Header().Set("Content-Length", fmt.Sprint(end-start+1))
		w.WriteHeader(nethttp.StatusPartialContent)
		_, _ = w.Write(payload[start : end+1])
	}))
	defer server.Close()
	destination := filepath.Join(t.TempDir(), "segmented.bin")
	workPath := destination + ".downpeed"
	var lastProgress download.TransferProgress
	limiter := &countingLimiter{}

	result, err := NewDownloader(server.Client()).Download(context.Background(), download.TransferRequest{
		URL:           server.URL + "/segmented.bin",
		Destination:   destination,
		WorkPath:      workPath,
		ExpectedSize:  int64(len(payload)),
		AllowSegments: true,
		Validator:     download.ResourceValidator{ETag: `"release-v1"`},
		Limiter:       limiter,
	}, func(progress download.TransferProgress) { lastProgress = progress })
	if err != nil {
		t.Fatal(err)
	}
	written, err := os.ReadFile(destination)
	if err != nil || !bytes.Equal(written, payload) {
		t.Fatalf("segmented file mismatch: size=%d error=%v", len(written), err)
	}
	checkpoint := newTransferCheckpoint(int64(len(payload)), segmentedConnectionCount)
	expectedRanges := make([]string, 0, len(checkpoint.Segments))
	for _, segment := range checkpoint.Segments {
		expectedRanges = append(expectedRanges, fmt.Sprintf("bytes=%d-%d", segment.Start, segment.End))
	}
	requestMu.Lock()
	sort.Strings(ranges)
	requestMu.Unlock()
	sort.Strings(expectedRanges)
	if len(ranges) != segmentedConnectionCount || fmt.Sprint(ranges) != fmt.Sprint(expectedRanges) {
		t.Fatalf("ranges = %v, want %v", ranges, expectedRanges)
	}
	if result.Size != int64(len(payload)) || lastProgress.Downloaded != result.Size || lastProgress.Checkpoint == nil {
		t.Fatalf("result = %#v, progress = %#v", result, lastProgress)
	}
	if limiter.Total() != int64(len(payload)) {
		t.Fatalf("limited segmented bytes = %d, want %d", limiter.Total(), len(payload))
	}
	if _, err = os.Stat(workPath); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("temporary file still exists: %v", err)
	}
}

func TestDownloaderDoesNotPublishSegmentsWhenIfRangeFails(t *testing.T) {
	payloadSize := int64(segmentedTransferMinSize)
	server := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, r *nethttp.Request) {
		if got := r.Header.Get("If-Range"); got != `"release-v1"` {
			t.Errorf("If-Range = %q, want release-v1", got)
		}
		w.Header().Set("ETag", `"release-v2"`)
		w.WriteHeader(nethttp.StatusOK)
		_, _ = w.Write([]byte("changed"))
	}))
	defer server.Close()
	destination := filepath.Join(t.TempDir(), "changed-segments.bin")
	workPath := destination + ".downpeed"

	_, err := NewDownloader(server.Client()).Download(context.Background(), download.TransferRequest{
		URL:           server.URL,
		Destination:   destination,
		WorkPath:      workPath,
		ExpectedSize:  payloadSize,
		AllowSegments: true,
		Validator:     download.ResourceValidator{ETag: `"release-v1"`},
	}, nil)
	if !errors.Is(err, download.ErrRemoteChanged) {
		t.Fatalf("error = %v, want ErrRemoteChanged", err)
	}
	if _, statErr := os.Stat(destination); !errors.Is(statErr, os.ErrNotExist) {
		t.Fatalf("changed segmented resource was published: %v", statErr)
	}
	if _, statErr := os.Stat(workPath); !errors.Is(statErr, os.ErrNotExist) {
		t.Fatalf("changed segmented work file remains: %v", statErr)
	}
}

func TestDownloaderKeepsSingleConnectionFallback(t *testing.T) {
	tests := []struct {
		name          string
		size          int
		allowSegments bool
	}{
		{name: "range capability unavailable", size: int(segmentedTransferMinSize + 1)},
		{name: "range capable file is small", size: int(segmentedTransferMinSize - 1), allowSegments: true},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			payload := bytes.Repeat([]byte("s"), test.size)
			requests := 0
			server := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, r *nethttp.Request) {
				requests++
				if value := r.Header.Get("Range"); value != "" {
					t.Errorf("unexpected Range = %q", value)
				}
				w.Header().Set("Content-Length", fmt.Sprint(len(payload)))
				_, _ = w.Write(payload)
			}))
			defer server.Close()
			destination := filepath.Join(t.TempDir(), "single.bin")

			_, err := NewDownloader(server.Client()).Download(context.Background(), download.TransferRequest{
				URL:           server.URL,
				Destination:   destination,
				WorkPath:      destination + ".downpeed",
				ExpectedSize:  int64(len(payload)),
				AllowSegments: test.allowSegments,
			}, nil)
			if err != nil {
				t.Fatal(err)
			}
			if requests != 1 {
				t.Fatalf("requests = %d, want 1", requests)
			}
		})
	}
}

func TestDownloaderPausesAndResumesIncompleteSegments(t *testing.T) {
	payload := bytes.Repeat([]byte("checkpoint-data"), 288*1024)
	var requestMu sync.Mutex
	phase := 1
	secondRanges := make([]string, 0, segmentedConnectionCount)
	server := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, r *nethttp.Request) {
		start, end, ok := readRequestedRange(r.Header.Get("Range"))
		if !ok || start < 0 || end < start || end >= int64(len(payload)) {
			w.WriteHeader(nethttp.StatusRequestedRangeNotSatisfiable)
			return
		}
		requestMu.Lock()
		requestPhase := phase
		if requestPhase == 2 {
			secondRanges = append(secondRanges, r.Header.Get("Range"))
		}
		requestMu.Unlock()
		w.Header().Set("Content-Range", fmt.Sprintf("bytes %d-%d/%d", start, end, len(payload)))
		w.Header().Set("Content-Length", fmt.Sprint(end-start+1))
		w.WriteHeader(nethttp.StatusPartialContent)
		flusher := w.(nethttp.Flusher)
		for offset := start; offset <= end; offset += 8 * 1024 {
			limit := offset + 8*1024 - 1
			if limit > end {
				limit = end
			}
			if _, err := w.Write(payload[offset : limit+1]); err != nil {
				return
			}
			flusher.Flush()
			if requestPhase == 1 {
				time.Sleep(4 * time.Millisecond)
			}
		}
	}))
	defer server.Close()
	destination := filepath.Join(t.TempDir(), "resume-segments.bin")
	workPath := destination + ".downpeed"
	ctx, pause := context.WithCancelCause(context.Background())
	var pauseOnce sync.Once
	var savedCheckpoint *download.TransferCheckpoint

	_, err := NewDownloader(server.Client()).Download(ctx, download.TransferRequest{
		URL:           server.URL,
		Destination:   destination,
		WorkPath:      workPath,
		ExpectedSize:  int64(len(payload)),
		AllowSegments: true,
		Validator:     download.ResourceValidator{ETag: `"release-v1"`},
	}, func(progress download.TransferProgress) {
		savedCheckpoint = download.CloneTransferCheckpoint(progress.Checkpoint)
		if progress.Downloaded > 0 {
			pauseOnce.Do(func() { pause(download.ErrTransferPaused) })
		}
	})
	if !errors.Is(err, context.Canceled) || savedCheckpoint == nil {
		t.Fatalf("pause error = %v, checkpoint = %#v", err, savedCheckpoint)
	}
	downloaded, err := download.ValidateTransferCheckpoint(savedCheckpoint, int64(len(payload)))
	if err != nil || downloaded <= 0 || downloaded >= int64(len(payload)) {
		t.Fatalf("paused checkpoint downloaded = %d, error = %v", downloaded, err)
	}
	if info, statErr := os.Stat(workPath); statErr != nil || info.Size() != int64(len(payload)) {
		t.Fatalf("preallocated work file = %#v, error = %v", info, statErr)
	}
	expectedRanges := make([]string, 0, len(savedCheckpoint.Segments))
	for _, segment := range savedCheckpoint.Segments {
		if segment.Completed < segment.End-segment.Start+1 {
			expectedRanges = append(expectedRanges, fmt.Sprintf("bytes=%d-%d", segment.Start+segment.Completed, segment.End))
		}
	}
	requestMu.Lock()
	phase = 2
	requestMu.Unlock()

	_, err = NewDownloader(server.Client()).Download(context.Background(), download.TransferRequest{
		URL:           server.URL,
		Destination:   destination,
		WorkPath:      workPath,
		Offset:        downloaded,
		ExpectedSize:  int64(len(payload)),
		AllowSegments: true,
		Validator:     download.ResourceValidator{ETag: `"release-v1"`},
		Checkpoint:    savedCheckpoint,
	}, nil)
	if err != nil {
		t.Fatal(err)
	}
	requestMu.Lock()
	sort.Strings(secondRanges)
	requestMu.Unlock()
	sort.Strings(expectedRanges)
	if fmt.Sprint(secondRanges) != fmt.Sprint(expectedRanges) {
		t.Fatalf("resume ranges = %v, want %v", secondRanges, expectedRanges)
	}
	written, err := os.ReadFile(destination)
	if err != nil || !bytes.Equal(written, payload) {
		t.Fatalf("resumed segmented file mismatch: size=%d error=%v", len(written), err)
	}
}

func TestDownloaderRejectsMalformedSegmentRangeWithoutPublishing(t *testing.T) {
	payloadSize := int64(segmentedTransferMinSize)
	server := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, _ *nethttp.Request) {
		w.Header().Set("Content-Range", fmt.Sprintf("bytes 0-1/%d", payloadSize))
		w.Header().Set("Content-Length", "2")
		w.WriteHeader(nethttp.StatusPartialContent)
		_, _ = w.Write([]byte("no"))
	}))
	defer server.Close()
	destination := filepath.Join(t.TempDir(), "malformed.bin")
	workPath := destination + ".downpeed"

	_, err := NewDownloader(server.Client()).Download(context.Background(), download.TransferRequest{
		URL: server.URL, Destination: destination, WorkPath: workPath,
		ExpectedSize: payloadSize, AllowSegments: true,
		Validator: download.ResourceValidator{ETag: `"release-v1"`},
	}, nil)
	if !errors.Is(err, download.ErrResumeNotSupported) {
		t.Fatalf("error = %v, want ErrResumeNotSupported", err)
	}
	if _, statErr := os.Stat(destination); !errors.Is(statErr, os.ErrNotExist) {
		t.Fatalf("final file exists: %v", statErr)
	}
	if _, statErr := os.Stat(workPath); !errors.Is(statErr, os.ErrNotExist) {
		t.Fatalf("work file exists after consistency failure: %v", statErr)
	}
}

func TestDownloaderDoesNotPublishTruncatedSegment(t *testing.T) {
	payload := bytes.Repeat([]byte("t"), int(segmentedTransferMinSize))
	server := httptest.NewServer(nethttp.HandlerFunc(func(w nethttp.ResponseWriter, r *nethttp.Request) {
		start, end, ok := readRequestedRange(r.Header.Get("Range"))
		if !ok {
			w.WriteHeader(nethttp.StatusBadRequest)
			return
		}
		w.Header().Set("Content-Range", fmt.Sprintf("bytes %d-%d/%d", start, end, len(payload)))
		w.Header().Set("Content-Length", fmt.Sprint(end-start+1))
		w.WriteHeader(nethttp.StatusPartialContent)
		if start == 0 {
			end--
		}
		_, _ = w.Write(payload[start : end+1])
	}))
	defer server.Close()
	destination := filepath.Join(t.TempDir(), "truncated.bin")
	workPath := destination + ".downpeed"

	_, err := NewDownloader(server.Client()).Download(context.Background(), download.TransferRequest{
		URL: server.URL, Destination: destination, WorkPath: workPath,
		ExpectedSize: int64(len(payload)), AllowSegments: true,
		Validator: download.ResourceValidator{ETag: `"release-v1"`},
	}, nil)
	if err == nil {
		t.Fatal("error = nil")
	}
	if _, statErr := os.Stat(destination); !errors.Is(statErr, os.ErrNotExist) {
		t.Fatalf("truncated transfer published final file: %v", statErr)
	}
	if _, statErr := os.Stat(workPath); !errors.Is(statErr, os.ErrNotExist) {
		t.Fatalf("work file exists after truncated transfer: %v", statErr)
	}
}

func TestDownloaderRejectsSegmentedTransferWithoutValidator(t *testing.T) {
	destination := filepath.Join(t.TempDir(), "unsafe-segments.bin")
	_, err := NewDownloader(nil).Download(context.Background(), download.TransferRequest{
		URL:           "https://example.com/unsafe-segments.bin",
		Destination:   destination,
		WorkPath:      destination + ".downpeed",
		ExpectedSize:  segmentedTransferMinSize,
		AllowSegments: true,
	}, nil)
	if !errors.Is(err, download.ErrResumeNotSupported) {
		t.Fatalf("error = %v, want ErrResumeNotSupported", err)
	}
}

func readRequestedRange(value string) (start int64, end int64, ok bool) {
	if _, err := fmt.Sscanf(value, "bytes=%d-%d", &start, &end); err != nil {
		return 0, 0, false
	}
	return start, end, true
}

type countingLimiter struct {
	mu    sync.Mutex
	total int64
}

func (limiter *countingLimiter) WaitN(_ context.Context, count int) error {
	limiter.mu.Lock()
	limiter.total += int64(count)
	limiter.mu.Unlock()
	return nil
}

func (limiter *countingLimiter) Total() int64 {
	limiter.mu.Lock()
	defer limiter.mu.Unlock()
	return limiter.total
}
