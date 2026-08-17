package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	enginediagnostics "github.com/wfu-work/downpeed-fluter/backend/internal/diagnostics"
	"github.com/wfu-work/downpeed-fluter/backend/pkg/api"
)

func TestDiagnosticsEndpointsReturnSnapshotAndArchive(t *testing.T) {
	startedAt := time.Date(2026, time.August, 17, 1, 0, 0, 0, time.UTC)
	snapshot := enginediagnostics.Snapshot{
		GeneratedAt: startedAt.Add(time.Minute),
		Storage: enginediagnostics.StorageInfo{
			DataDirectory:     "~/Library/Application Support/Downpeed",
			DatabasePath:      "~/Library/Application Support/Downpeed/tasks.db",
			DatabaseSizeBytes: 2048,
			DatabaseAvailable: true,
		},
		Tasks: enginediagnostics.TaskSummary{Total: 3, Active: 1},
	}
	server := New(startedAt, WithDiagnosticsService(diagnosticsProviderStub{
		snapshot: snapshot,
		archive: enginediagnostics.Archive{
			Filename: "downpeed-diagnostics-20260817-010100Z.zip",
			Bytes:    []byte("PK diagnostic archive"),
		},
	}))

	getResponse := httptest.NewRecorder()
	server.Handler().ServeHTTP(getResponse, httptest.NewRequest(http.MethodGet, "/api/v1/diagnostics", nil))
	if getResponse.Code != http.StatusOK {
		t.Fatalf("GET status = %d; body = %s", getResponse.Code, getResponse.Body.String())
	}
	var envelope api.Envelope[enginediagnostics.Snapshot]
	if err := json.NewDecoder(getResponse.Body).Decode(&envelope); err != nil {
		t.Fatal(err)
	}
	if envelope.Data.Storage.DatabaseSizeBytes != 2048 || envelope.Data.Tasks.Active != 1 {
		t.Fatalf("snapshot = %#v", envelope.Data)
	}

	exportResponse := httptest.NewRecorder()
	server.Handler().ServeHTTP(exportResponse, httptest.NewRequest(http.MethodPost, "/api/v1/diagnostics/export", nil))
	if exportResponse.Code != http.StatusOK {
		t.Fatalf("POST status = %d; body = %s", exportResponse.Code, exportResponse.Body.String())
	}
	if got := exportResponse.Header().Get("Content-Type"); got != "application/zip" {
		t.Fatalf("Content-Type = %q", got)
	}
	if got := exportResponse.Header().Get("X-Downpeed-Filename"); got != "downpeed-diagnostics-20260817-010100Z.zip" {
		t.Fatalf("filename = %q", got)
	}
	if got := exportResponse.Header().Get("Cache-Control"); got != "no-store" {
		t.Fatalf("Cache-Control = %q", got)
	}
	if exportResponse.Body.String() != "PK diagnostic archive" {
		t.Fatalf("archive = %q", exportResponse.Body.String())
	}
}

func TestDiagnosticsEndpointNormalizesProviderFailure(t *testing.T) {
	server := New(time.Now(), WithDiagnosticsService(diagnosticsProviderStub{err: errors.New("database unavailable")}))
	response := httptest.NewRecorder()
	server.Handler().ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/api/v1/diagnostics", nil))
	assertAPIError(t, response, http.StatusServiceUnavailable, "diagnostics_unavailable", true)
}

type diagnosticsProviderStub struct {
	snapshot enginediagnostics.Snapshot
	archive  enginediagnostics.Archive
	err      error
}

func (stub diagnosticsProviderStub) Snapshot(context.Context) (enginediagnostics.Snapshot, error) {
	return stub.snapshot, stub.err
}

func (stub diagnosticsProviderStub) Export(context.Context) (enginediagnostics.Archive, error) {
	return stub.archive, stub.err
}
