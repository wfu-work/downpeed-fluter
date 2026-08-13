package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/wfu-work/downpeed-fluter/backend/internal/download"
	httpprotocol "github.com/wfu-work/downpeed-fluter/backend/internal/protocol/http"
	"github.com/wfu-work/downpeed-fluter/backend/internal/repository"
	"github.com/wfu-work/downpeed-fluter/backend/pkg/api"
)

func TestHealth(t *testing.T) {
	server := New(time.Date(2026, time.August, 11, 1, 0, 0, 0, time.UTC))
	request := httptest.NewRequest(http.MethodGet, "/api/v1/health", nil)
	request.Header.Set("X-Request-ID", "test-request")
	response := httptest.NewRecorder()

	server.Handler().ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusOK)
	}
	if got := response.Header().Get("Content-Type"); got != "application/json; charset=utf-8" {
		t.Fatalf("Content-Type = %q", got)
	}
	var envelope api.Envelope[Health]
	if err := json.NewDecoder(response.Body).Decode(&envelope); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if envelope.Error != nil {
		t.Fatalf("error = %#v, want nil", envelope.Error)
	}
	if envelope.Data.Status != "ok" {
		t.Fatalf("status = %q, want ok", envelope.Data.Status)
	}
	if envelope.RequestID != "test-request" {
		t.Fatalf("request ID = %q, want test-request", envelope.RequestID)
	}
}

func TestInfo(t *testing.T) {
	startedAt := time.Now().Add(-time.Second).UTC()
	server := New(startedAt)
	response := httptest.NewRecorder()

	server.Handler().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodGet, "/api/v1/info", nil),
	)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusOK)
	}
	var envelope api.Envelope[Info]
	if err := json.NewDecoder(response.Body).Decode(&envelope); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if envelope.Data.Name != "Downpeed Engine" {
		t.Fatalf("name = %q", envelope.Data.Name)
	}
	if envelope.Data.UptimeMS < 900 {
		t.Fatalf("uptime = %dms, want at least 900ms", envelope.Data.UptimeMS)
	}
	if envelope.RequestID == "" {
		t.Fatal("request ID is empty")
	}
}

func TestSettingsAPIReadsUpdatesAndRejectsInvalidDirectory(t *testing.T) {
	initial := t.TempDir()
	selected := t.TempDir()
	settings, err := download.NewSettingsManager(context.Background(), nil, initial)
	if err != nil {
		t.Fatal(err)
	}
	server := New(time.Now(), WithSettingsService(settings))
	defer server.Close()

	getResponse := httptest.NewRecorder()
	server.Handler().ServeHTTP(getResponse, httptest.NewRequest(http.MethodGet, "/api/v1/settings", nil))
	if getResponse.Code != http.StatusOK {
		t.Fatalf("get status = %d, body = %s", getResponse.Code, getResponse.Body.String())
	}
	var getEnvelope api.Envelope[download.EngineSettings]
	if err = json.NewDecoder(getResponse.Body).Decode(&getEnvelope); err != nil {
		t.Fatal(err)
	}
	if getEnvelope.Data.DefaultDownloadDirectory != initial {
		t.Fatalf("settings = %#v", getEnvelope.Data)
	}
	if getEnvelope.Data.BitTorrent != download.DefaultBTPolicySettings() {
		t.Fatalf("BT policy = %#v", getEnvelope.Data.BitTorrent)
	}

	policy := download.DefaultBTPolicySettings()
	policy.MaxPeerConnections = 20
	updateBody, _ := json.Marshal(download.EngineSettings{DefaultDownloadDirectory: selected, BitTorrent: policy})
	putResponse := httptest.NewRecorder()
	server.Handler().ServeHTTP(putResponse, httptest.NewRequest(http.MethodPut, "/api/v1/settings", bytes.NewReader(updateBody)))
	if putResponse.Code != http.StatusOK {
		t.Fatalf("put status = %d, body = %s", putResponse.Code, putResponse.Body.String())
	}
	var putEnvelope api.Envelope[download.EngineSettings]
	if err = json.NewDecoder(putResponse.Body).Decode(&putEnvelope); err != nil {
		t.Fatal(err)
	}
	if putEnvelope.Data.DefaultDownloadDirectory != selected || putEnvelope.Data.BitTorrent.MaxPeerConnections != 20 {
		t.Fatalf("updated settings = %#v", putEnvelope.Data)
	}

	legacyDirectory := t.TempDir()
	legacyBody, _ := json.Marshal(map[string]string{"defaultDownloadDirectory": legacyDirectory})
	legacyResponse := httptest.NewRecorder()
	server.Handler().ServeHTTP(legacyResponse, httptest.NewRequest(http.MethodPut, "/api/v1/settings", bytes.NewReader(legacyBody)))
	if legacyResponse.Code != http.StatusOK {
		t.Fatalf("legacy update status = %d, body = %s", legacyResponse.Code, legacyResponse.Body.String())
	}
	var legacyEnvelope api.Envelope[download.EngineSettings]
	if err = json.NewDecoder(legacyResponse.Body).Decode(&legacyEnvelope); err != nil {
		t.Fatal(err)
	}
	if legacyEnvelope.Data.DefaultDownloadDirectory != legacyDirectory || legacyEnvelope.Data.BitTorrent.MaxPeerConnections != 20 {
		t.Fatalf("legacy update reset policy: %#v", legacyEnvelope.Data)
	}

	invalidBody, _ := json.Marshal(download.EngineSettings{DefaultDownloadDirectory: filepath.Join(selected, "missing")})
	invalidResponse := httptest.NewRecorder()
	server.Handler().ServeHTTP(invalidResponse, httptest.NewRequest(http.MethodPut, "/api/v1/settings", bytes.NewReader(invalidBody)))
	assertAPIError(t, invalidResponse, http.StatusBadRequest, "invalid_download_directory", false)

	unsafe := download.DefaultBTPolicySettings()
	unsafe.UploadEnabled = true
	unsafeBody, _ := json.Marshal(download.EngineSettings{DefaultDownloadDirectory: selected, BitTorrent: unsafe})
	unsafeResponse := httptest.NewRecorder()
	server.Handler().ServeHTTP(unsafeResponse, httptest.NewRequest(http.MethodPut, "/api/v1/settings", bytes.NewReader(unsafeBody)))
	assertAPIError(t, unsafeResponse, http.StatusBadRequest, "invalid_bt_policy", false)
}

func TestHealthRejectsWrongMethod(t *testing.T) {
	server := New(time.Now())
	response := httptest.NewRecorder()

	server.Handler().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodPost, "/api/v1/health", nil),
	)

	if response.Code != http.StatusMethodNotAllowed {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusMethodNotAllowed)
	}
}

func TestResolveDownloadReturnsStableEnvelope(t *testing.T) {
	resolver := stubResolver{resolve: func(_ context.Context, input download.ResolveRequest) (download.Resolution, error) {
		if input.URL != "https://example.com/file.zip" {
			t.Fatalf("URL = %q", input.URL)
		}
		return download.Resolution{
			URL:          input.URL,
			FinalURL:     input.URL,
			FileName:     "file.zip",
			Size:         1024,
			ContentType:  "application/zip",
			AcceptRanges: true,
			ETag:         `"release-v1"`,
			LastModified: "Tue, 11 Aug 2026 01:02:03 GMT",
		}, nil
	}}
	server := New(time.Now(), WithResolver(resolver))
	request := httptest.NewRequest(
		http.MethodPost,
		"/api/v1/tasks/resolve",
		bytes.NewBufferString(`{"url":"https://example.com/file.zip"}`),
	)
	request.Header.Set("X-Request-ID", "resolve-request")
	response := httptest.NewRecorder()

	server.Handler().ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	var envelope api.Envelope[download.Resolution]
	if err := json.NewDecoder(response.Body).Decode(&envelope); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if envelope.Data.FileName != "file.zip" || envelope.Data.ETag != `"release-v1"` || envelope.Data.LastModified == "" || envelope.RequestID != "resolve-request" {
		t.Fatalf("envelope = %#v", envelope)
	}
}

func TestResolveDownloadRejectsInvalidJSON(t *testing.T) {
	server := New(time.Now(), WithResolver(stubResolver{}))
	response := httptest.NewRecorder()
	server.Handler().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodPost, "/api/v1/tasks/resolve", bytes.NewBufferString(`{"unknown":true}`)),
	)

	assertAPIError(t, response, http.StatusBadRequest, "invalid_request", false)
}

func TestResolveDownloadMapsResolverErrors(t *testing.T) {
	tests := []struct {
		name      string
		err       error
		status    int
		code      string
		retryable bool
	}{
		{name: "invalid", err: download.ErrInvalidRequest, status: http.StatusBadRequest, code: "invalid_request"},
		{name: "scheme", err: download.ErrUnsupportedScheme, status: http.StatusBadRequest, code: "unsupported_scheme"},
		{name: "remote", err: errors.New("remote unavailable"), status: http.StatusBadGateway, code: "resolve_failed", retryable: true},
		{name: "timeout", err: context.DeadlineExceeded, status: http.StatusGatewayTimeout, code: "resolve_failed", retryable: true},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			server := New(time.Now(), WithResolver(stubResolver{
				resolve: func(context.Context, download.ResolveRequest) (download.Resolution, error) {
					return download.Resolution{}, test.err
				},
			}))
			response := httptest.NewRecorder()
			server.Handler().ServeHTTP(
				response,
				httptest.NewRequest(http.MethodPost, "/api/v1/tasks/resolve", bytes.NewBufferString(`{"url":"https://example.com/file"}`)),
			)

			assertAPIError(t, response, test.status, test.code, test.retryable)
		})
	}
}

func TestBTResolveEndpointsUseBoundedStableContracts(t *testing.T) {
	resolver := &stubBTResolver{
		resolveMagnet: func(_ context.Context, value string) (download.BTResolution, error) {
			if !strings.HasPrefix(value, "magnet:") {
				t.Fatalf("magnet = %q", value)
			}
			return download.BTResolution{
				SourceType: download.BTSourceMagnet,
				Name:       "Archive",
				InfoHash:   "0123456789abcdef0123456789abcdef01234567",
				TotalSize:  -1,
				Files:      []download.BTFile{},
				Trackers:   []download.BTTracker{},
			}, nil
		},
		resolveTorrent: func(_ context.Context, value []byte) (download.BTResolution, error) {
			if string(value) != "torrent-bytes" {
				t.Fatalf("torrent bytes = %q", value)
			}
			return download.BTResolution{
				SourceType:        download.BTSourceTorrent,
				Name:              "Archive",
				MetadataAvailable: true,
				TotalSize:         12,
				Files: []download.BTFile{
					{Index: 0, Path: "Archive/file.bin", Size: 12},
				},
				Trackers: []download.BTTracker{},
			}, nil
		},
	}
	server := New(time.Now(), WithBTResolver(resolver))
	defer server.Close()

	magnetResponse := httptest.NewRecorder()
	server.Handler().ServeHTTP(
		magnetResponse,
		httptest.NewRequest(http.MethodPost, "/api/v1/bt/resolve/magnet", bytes.NewBufferString(
			`{"magnet":"magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567"}`,
		)),
	)
	if magnetResponse.Code != http.StatusOK {
		t.Fatalf("magnet status = %d, body = %s", magnetResponse.Code, magnetResponse.Body.String())
	}
	var magnet api.Envelope[download.BTResolution]
	if err := json.NewDecoder(magnetResponse.Body).Decode(&magnet); err != nil {
		t.Fatal(err)
	}
	if magnet.Data.SourceType != download.BTSourceMagnet || magnet.Data.MetadataAvailable {
		t.Fatalf("magnet = %#v", magnet.Data)
	}

	torrentResponse := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/api/v1/bt/resolve/torrent", bytes.NewBufferString("torrent-bytes"))
	request.Header.Set("Content-Type", "application/x-bittorrent")
	server.Handler().ServeHTTP(torrentResponse, request)
	if torrentResponse.Code != http.StatusOK {
		t.Fatalf("torrent status = %d, body = %s", torrentResponse.Code, torrentResponse.Body.String())
	}
	var torrent api.Envelope[download.BTResolution]
	if err := json.NewDecoder(torrentResponse.Body).Decode(&torrent); err != nil {
		t.Fatal(err)
	}
	if len(torrent.Data.Files) != 1 || torrent.Data.TotalSize != 12 {
		t.Fatalf("torrent = %#v", torrent.Data)
	}
}

func TestBTResolveEndpointsMapSafetyErrors(t *testing.T) {
	server := New(time.Now(), WithBTResolver(&stubBTResolver{
		resolveMagnet: func(context.Context, string) (download.BTResolution, error) {
			return download.BTResolution{}, download.ErrBTInvalidMagnet
		},
		resolveTorrent: func(context.Context, []byte) (download.BTResolution, error) {
			return download.BTResolution{}, download.ErrBTPathUnsafe
		},
	}))
	defer server.Close()

	magnet := httptest.NewRecorder()
	server.Handler().ServeHTTP(magnet, httptest.NewRequest(
		http.MethodPost,
		"/api/v1/bt/resolve/magnet",
		bytes.NewBufferString(`{"magnet":"invalid"}`),
	))
	assertAPIError(t, magnet, http.StatusBadRequest, "bt_invalid_magnet", false)

	torrent := httptest.NewRecorder()
	server.Handler().ServeHTTP(torrent, httptest.NewRequest(
		http.MethodPost,
		"/api/v1/bt/resolve/torrent",
		bytes.NewBufferString("unsafe"),
	))
	assertAPIError(t, torrent, http.StatusBadRequest, "bt_path_unsafe", false)
}

func TestCreateBTTaskUsesExplicitRestrictedContract(t *testing.T) {
	tasks := &stubTaskService{
		createBT: func(_ context.Context, input download.CreateBTTaskRequest) (download.Task, error) {
			if string(input.Metadata) != "torrent-bytes" || input.SaveDirectory != "/tmp/downloads" {
				t.Fatalf("input = %#v", input)
			}
			if len(input.SelectedFileIndexes) != 1 || input.SelectedFileIndexes[0] != 2 || len(input.ExplicitPeers) != 1 || input.ExplicitPeers[0] != "8.8.8.8:6881" {
				t.Fatalf("selection/peers = %#v", input)
			}
			return download.Task{ID: "bt-1", Protocol: download.ProtocolBT, State: download.TaskStateQueued}, nil
		},
	}
	server := New(time.Now(), WithTaskService(tasks))
	defer server.Close()
	response := httptest.NewRecorder()
	server.Handler().ServeHTTP(response, httptest.NewRequest(
		http.MethodPost,
		"/api/v1/bt/tasks",
		bytes.NewBufferString(`{"metadata":"dG9ycmVudC1ieXRlcw==","saveDirectory":"/tmp/downloads","selectedFileIndexes":[2],"explicitPeers":["8.8.8.8:6881"]}`),
	))
	if response.Code != http.StatusCreated {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	var envelope api.Envelope[download.Task]
	if err := json.NewDecoder(response.Body).Decode(&envelope); err != nil {
		t.Fatal(err)
	}
	if envelope.Data.ID != "bt-1" || envelope.Data.Protocol != download.ProtocolBT {
		t.Fatalf("task = %#v", envelope.Data)
	}
}

func TestBTDiagnosticsReturnsSanitizedLiveConnectionState(t *testing.T) {
	now := time.Date(2026, time.August, 12, 3, 0, 0, 0, time.UTC)
	tasks := &stubTaskService{
		diagnostics: func(_ context.Context, id string) (download.BTDiagnostics, error) {
			if id != "bt-1" {
				t.Fatalf("task id = %q", id)
			}
			return download.BTDiagnostics{
				TaskID: id, State: download.TaskStateDownloading, Live: true,
				Connections: download.BTConnectionDiagnostics{Configured: 2, Known: 2, Connected: 1, Pending: 1},
				Traffic:     download.BTTrafficDiagnostics{UsefulBytes: 1024, UploadedBytes: 0},
				Peers:       []download.BTPeerDiagnostics{{Address: "8.8.x.x:6881", Client: "test-peer", Network: "TCP", ReceivedBytes: 1024}},
				Policy: download.BTPolicyDiagnostics{
					MaxPeerConnections: download.DefaultBTPeerConnections,
					ExplicitPeersOnly:  true,
				}, UpdatedAt: now,
			}, nil
		},
	}
	server := New(time.Now(), WithTaskService(tasks))
	defer server.Close()
	response := httptest.NewRecorder()
	server.Handler().ServeHTTP(response, httptest.NewRequest(
		http.MethodGet,
		"/api/v1/tasks/bt-1/bt/diagnostics",
		nil,
	))
	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	var envelope api.Envelope[download.BTDiagnostics]
	if err := json.NewDecoder(response.Body).Decode(&envelope); err != nil {
		t.Fatal(err)
	}
	if !envelope.Data.Live || envelope.Data.Connections.Connected != 1 || len(envelope.Data.Peers) != 1 || envelope.Data.Peers[0].Address != "8.8.x.x:6881" || !envelope.Data.Policy.ExplicitPeersOnly || envelope.Data.Policy.UploadEnabled {
		t.Fatalf("diagnostics = %#v", envelope.Data)
	}
}

func TestBTDiagnosticsMapsTaskAndProtocolErrors(t *testing.T) {
	tests := []struct {
		name   string
		err    error
		status int
		code   string
	}{
		{name: "missing", err: download.ErrTaskNotFound, status: http.StatusNotFound, code: "task_not_found"},
		{name: "http task", err: download.ErrUnsupportedProtocol, status: http.StatusConflict, code: "bt_diagnostics_not_applicable"},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			server := New(time.Now(), WithTaskService(&stubTaskService{
				diagnostics: func(context.Context, string) (download.BTDiagnostics, error) {
					return download.BTDiagnostics{}, test.err
				},
			}))
			defer server.Close()
			response := httptest.NewRecorder()
			server.Handler().ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/api/v1/tasks/task-1/bt/diagnostics", nil))
			assertAPIError(t, response, test.status, test.code, false)
		})
	}
}

func TestCreateBTTaskMapsRestrictedTransferErrors(t *testing.T) {
	tests := []struct {
		name string
		err  error
		code string
	}{
		{name: "peer required", err: download.ErrBTPeerRequired, code: "bt_peer_required"},
		{name: "peer invalid", err: download.ErrBTPeerInvalid, code: "bt_peer_invalid"},
		{name: "selection", err: download.ErrBTFileSelection, code: "bt_file_selection_invalid"},
		{name: "metadata", err: download.ErrBTMetadataInvalid, code: "bt_metadata_invalid"},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			server := New(time.Now(), WithTaskService(&stubTaskService{
				createBT: func(context.Context, download.CreateBTTaskRequest) (download.Task, error) {
					return download.Task{}, test.err
				},
			}))
			defer server.Close()
			response := httptest.NewRecorder()
			server.Handler().ServeHTTP(response, httptest.NewRequest(
				http.MethodPost,
				"/api/v1/bt/tasks",
				bytes.NewBufferString(`{"metadata":"dG9ycmVudC1ieXRlcw==","saveDirectory":"/tmp/downloads","selectedFileIndexes":[0],"explicitPeers":["8.8.8.8:6881"]}`),
			))
			assertAPIError(t, response, http.StatusBadRequest, test.code, false)
		})
	}
}

func TestCreateTaskReturnsCreatedTask(t *testing.T) {
	tasks := &stubTaskService{
		create: func(_ context.Context, input download.CreateTaskRequest) (download.Task, error) {
			if input.FileName != "file.zip" || input.SaveDirectory != "/tmp/downloads" || input.ExpectedSize != 1572864 || !input.AcceptRanges || input.ETag != `"release-v1"` || input.LastModified == "" {
				t.Fatalf("input = %#v", input)
			}
			return download.Task{ID: "task-1", State: download.TaskStateDownloading, Total: -1}, nil
		},
	}
	server := New(time.Now(), WithTaskService(tasks))
	defer server.Close()
	response := httptest.NewRecorder()
	server.Handler().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodPost, "/api/v1/tasks", bytes.NewBufferString(
			`{"url":"https://example.com/file.zip","fileName":"file.zip","saveDirectory":"/tmp/downloads","expectedSize":1572864,"acceptRanges":true,"etag":"\"release-v1\"","lastModified":"Tue, 11 Aug 2026 01:02:03 GMT"}`,
		)),
	)

	if response.Code != http.StatusCreated {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	var envelope api.Envelope[download.Task]
	if err := json.NewDecoder(response.Body).Decode(&envelope); err != nil {
		t.Fatal(err)
	}
	if envelope.Data.ID != "task-1" || envelope.Data.State != download.TaskStateDownloading {
		t.Fatalf("task = %#v", envelope.Data)
	}
}

func TestCreateTasksBatchReturnsPerItemResults(t *testing.T) {
	created := 0
	tasks := &stubTaskService{
		create: func(_ context.Context, input download.CreateTaskRequest) (download.Task, error) {
			created++
			if input.FileName == "exists.zip" {
				return download.Task{}, download.ErrDestinationExists
			}
			return download.Task{ID: fmt.Sprintf("task-%d", created), FileName: input.FileName, State: download.TaskStateQueued}, nil
		},
	}
	server := New(time.Now(), WithTaskService(tasks))
	defer server.Close()
	response := httptest.NewRecorder()
	server.Handler().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodPost, "/api/v1/tasks/batch", bytes.NewBufferString(
			`{"tasks":[{"url":"https://example.com/one.zip","fileName":"one.zip","saveDirectory":"/tmp"},{"url":"https://example.com/exists.zip","fileName":"exists.zip","saveDirectory":"/tmp"}]}`,
		)),
	)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	var envelope api.Envelope[batchTaskResult]
	if err := json.NewDecoder(response.Body).Decode(&envelope); err != nil {
		t.Fatal(err)
	}
	if envelope.Data.Succeeded != 1 || envelope.Data.Failed != 1 || len(envelope.Data.Items) != 2 {
		t.Fatalf("result = %#v", envelope.Data)
	}
	if envelope.Data.Items[0].Task == nil || envelope.Data.Items[0].ID != "task-1" {
		t.Fatalf("first item = %#v", envelope.Data.Items[0])
	}
	if failure := envelope.Data.Items[1]; failure.Error == nil || failure.Error.Code != "destination_exists" || failure.Index != 1 {
		t.Fatalf("second item = %#v", failure)
	}
}

func TestActOnTasksBatchUsesOneActionAndKeepsFailuresVisible(t *testing.T) {
	paused := make([]string, 0, 2)
	tasks := &stubTaskService{
		pause: func(_ context.Context, id string) (download.Task, error) {
			paused = append(paused, id)
			if id == "missing" {
				return download.Task{}, download.ErrTaskNotFound
			}
			return download.Task{ID: id, State: download.TaskStatePaused}, nil
		},
	}
	server := New(time.Now(), WithTaskService(tasks))
	defer server.Close()
	response := httptest.NewRecorder()
	server.Handler().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodPost, "/api/v1/tasks/batch/actions", bytes.NewBufferString(
			`{"ids":["task-1","missing"],"action":"pause"}`,
		)),
	)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	var envelope api.Envelope[batchTaskResult]
	if err := json.NewDecoder(response.Body).Decode(&envelope); err != nil {
		t.Fatal(err)
	}
	if fmt.Sprint(paused) != "[task-1 missing]" || envelope.Data.Succeeded != 1 || envelope.Data.Failed != 1 {
		t.Fatalf("paused = %v, result = %#v", paused, envelope.Data)
	}
	if envelope.Data.Items[1].Error == nil || envelope.Data.Items[1].Error.Code != "task_not_found" {
		t.Fatalf("failure = %#v", envelope.Data.Items[1])
	}
}

func TestBatchEndpointsRejectInvalidBoundsAndActions(t *testing.T) {
	server := New(time.Now(), WithTaskService(&stubTaskService{}))
	defer server.Close()

	for _, test := range []struct {
		path string
		body string
		code string
	}{
		{path: "/api/v1/tasks/batch", body: `{"tasks":[]}`, code: "invalid_batch_size"},
		{path: "/api/v1/tasks/batch/actions", body: `{"ids":["task-1"],"action":"delete"}`, code: "invalid_batch_action"},
	} {
		response := httptest.NewRecorder()
		server.Handler().ServeHTTP(response, httptest.NewRequest(http.MethodPost, test.path, bytes.NewBufferString(test.body)))
		assertAPIError(t, response, http.StatusBadRequest, test.code, false)
	}

	tooMany := batchCreateTasksRequest{Tasks: make([]download.CreateTaskRequest, maxBatchTasks+1)}
	body, err := json.Marshal(tooMany)
	if err != nil {
		t.Fatal(err)
	}
	response := httptest.NewRecorder()
	server.Handler().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodPost, "/api/v1/tasks/batch", bytes.NewReader(body)),
	)
	assertAPIError(t, response, http.StatusBadRequest, "invalid_batch_size", false)
}

func TestCancelTaskMapsNotFound(t *testing.T) {
	tasks := &stubTaskService{
		cancel: func(context.Context, string) (download.Task, error) {
			return download.Task{}, download.ErrTaskNotFound
		},
	}
	server := New(time.Now(), WithTaskService(tasks))
	defer server.Close()
	response := httptest.NewRecorder()
	server.Handler().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodDelete, "/api/v1/tasks/missing", nil),
	)

	assertAPIError(t, response, http.StatusNotFound, "task_not_found", false)
}

func TestCancelTaskSupportsExplicitAndLegacyRESTContracts(t *testing.T) {
	var canceled []string
	tasks := &stubTaskService{
		cancel: func(_ context.Context, id string) (download.Task, error) {
			canceled = append(canceled, id)
			return download.Task{ID: id, State: download.TaskStateCanceled}, nil
		},
	}
	server := New(time.Now(), WithTaskService(tasks))
	defer server.Close()

	for _, request := range []*http.Request{
		httptest.NewRequest(http.MethodPut, "/api/v1/tasks/task-new/cancel", nil),
		httptest.NewRequest(http.MethodDelete, "/api/v1/tasks/task-legacy", nil),
	} {
		response := httptest.NewRecorder()
		server.Handler().ServeHTTP(response, request)
		if response.Code != http.StatusOK {
			t.Fatalf("%s %s status = %d, body = %s", request.Method, request.URL.Path, response.Code, response.Body.String())
		}
	}
	if fmt.Sprint(canceled) != "[task-new task-legacy]" {
		t.Fatalf("canceled = %v", canceled)
	}
}

func TestDeleteTaskRecordReadsDeleteFilesQuery(t *testing.T) {
	var deletedID string
	var deleteFile bool
	server := New(time.Now(), WithTaskService(&stubTaskService{
		delete: func(_ context.Context, id string, value bool) (download.DeleteTaskResult, error) {
			deletedID = id
			deleteFile = value
			return download.DeleteTaskResult{ID: id, FileDeleted: value}, nil
		},
	}))
	defer server.Close()
	response := httptest.NewRecorder()
	server.Handler().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodDelete, "/api/v1/tasks/task-1/record?deleteFiles=true", nil),
	)
	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	var envelope api.Envelope[download.DeleteTaskResult]
	if err := json.NewDecoder(response.Body).Decode(&envelope); err != nil {
		t.Fatal(err)
	}
	if deletedID != "task-1" || !deleteFile || !envelope.Data.FileDeleted {
		t.Fatalf("deletedID = %q, deleteFile = %t, result = %#v", deletedID, deleteFile, envelope.Data)
	}
}

func TestDeleteTaskRecordRejectsInvalidDeleteFilesQuery(t *testing.T) {
	server := New(time.Now(), WithTaskService(&stubTaskService{}))
	defer server.Close()
	response := httptest.NewRecorder()
	server.Handler().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodDelete, "/api/v1/tasks/task-1/record?deleteFiles=sometimes", nil),
	)
	assertAPIError(t, response, http.StatusBadRequest, "invalid_request", false)
}

func TestDeleteTasksBatchKeepsPerItemFailuresVisible(t *testing.T) {
	var deleteFiles []bool
	server := New(time.Now(), WithTaskService(&stubTaskService{
		delete: func(_ context.Context, id string, deleteFile bool) (download.DeleteTaskResult, error) {
			deleteFiles = append(deleteFiles, deleteFile)
			if id == "active" {
				return download.DeleteTaskResult{}, download.ErrTaskInvalidState
			}
			return download.DeleteTaskResult{ID: id, FileDeleted: deleteFile}, nil
		},
	}))
	defer server.Close()
	response := httptest.NewRecorder()
	server.Handler().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodPost, "/api/v1/tasks/batch/delete", bytes.NewBufferString(
			`{"ids":["completed","active"],"deleteFiles":true}`,
		)),
	)
	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	var envelope api.Envelope[batchDeleteTaskResult]
	if err := json.NewDecoder(response.Body).Decode(&envelope); err != nil {
		t.Fatal(err)
	}
	if fmt.Sprint(deleteFiles) != "[true true]" || envelope.Data.Succeeded != 1 || envelope.Data.Failed != 1 {
		t.Fatalf("deleteFiles = %v, result = %#v", deleteFiles, envelope.Data)
	}
	if envelope.Data.Items[1].Error == nil || envelope.Data.Items[1].Error.Code != "invalid_task_state" {
		t.Fatalf("failed item = %#v", envelope.Data.Items[1])
	}
}

func TestDeleteCompletedTasksOnlyDeletesCompletedRecordsAndPreservesFilesByDefault(t *testing.T) {
	states := map[string]download.TaskState{
		"completed-1": download.TaskStateCompleted,
		"failed-1":    download.TaskStateFailed,
		"active-1":    download.TaskStateDownloading,
	}
	var deleted []string
	server := New(time.Now(), WithTaskService(&stubTaskService{
		list: func(context.Context) ([]download.Task, error) {
			return []download.Task{
				{ID: "completed-1", State: states["completed-1"]},
				{ID: "failed-1", State: states["failed-1"]},
				{ID: "active-1", State: states["active-1"]},
			}, nil
		},
		delete: func(_ context.Context, id string, deleteFile bool) (download.DeleteTaskResult, error) {
			if deleteFile {
				t.Fatal("clear completed unexpectedly requested file deletion")
			}
			deleted = append(deleted, id)
			return download.DeleteTaskResult{ID: id}, nil
		},
	}))
	defer server.Close()
	response := httptest.NewRecorder()
	server.Handler().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodDelete, "/api/v1/tasks/completed?deleteFiles=true", nil),
	)
	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	var envelope api.Envelope[batchDeleteTaskResult]
	if err := json.NewDecoder(response.Body).Decode(&envelope); err != nil {
		t.Fatal(err)
	}
	if fmt.Sprint(deleted) != "[completed-1]" || envelope.Data.Succeeded != 1 || envelope.Data.Failed != 0 {
		t.Fatalf("deleted = %v, result = %#v", deleted, envelope.Data)
	}
}

func TestPauseAndResumeTaskUseStableRESTContract(t *testing.T) {
	tasks := &stubTaskService{
		pause: func(_ context.Context, id string) (download.Task, error) {
			if id != "task-1" {
				t.Fatalf("pause id = %q", id)
			}
			return download.Task{ID: id, State: download.TaskStatePaused}, nil
		},
		resume: func(_ context.Context, id string) (download.Task, error) {
			return download.Task{ID: id, State: download.TaskStateDownloading}, nil
		},
	}
	server := New(time.Now(), WithTaskService(tasks))
	defer server.Close()

	for _, test := range []struct {
		path  string
		state download.TaskState
	}{
		{path: "/api/v1/tasks/task-1/pause", state: download.TaskStatePaused},
		{path: "/api/v1/tasks/task-1/resume", state: download.TaskStateDownloading},
	} {
		response := httptest.NewRecorder()
		server.Handler().ServeHTTP(response, httptest.NewRequest(http.MethodPut, test.path, nil))
		if response.Code != http.StatusOK {
			t.Fatalf("%s status = %d, body = %s", test.path, response.Code, response.Body.String())
		}
		var envelope api.Envelope[download.Task]
		if err := json.NewDecoder(response.Body).Decode(&envelope); err != nil {
			t.Fatal(err)
		}
		if envelope.Data.State != test.state {
			t.Fatalf("%s state = %q", test.path, envelope.Data.State)
		}
	}
}

func TestRetryTaskUsesStableRESTContract(t *testing.T) {
	server := New(time.Now(), WithTaskService(&stubTaskService{
		retry: func(_ context.Context, id string) (download.Task, error) {
			if id != "task-1" {
				t.Fatalf("retry id = %q", id)
			}
			return download.Task{ID: id, State: download.TaskStateDownloading}, nil
		},
	}))
	defer server.Close()
	response := httptest.NewRecorder()
	server.Handler().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodPost, "/api/v1/tasks/task-1/retry", nil),
	)
	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	var envelope api.Envelope[download.Task]
	if err := json.NewDecoder(response.Body).Decode(&envelope); err != nil {
		t.Fatal(err)
	}
	if envelope.Data.ID != "task-1" || envelope.Data.State != download.TaskStateDownloading {
		t.Fatalf("task = %#v", envelope.Data)
	}
}

func TestRetryTaskMapsUnsafeRetryToStableConflict(t *testing.T) {
	server := New(time.Now(), WithTaskService(&stubTaskService{
		retry: func(context.Context, string) (download.Task, error) {
			return download.Task{}, download.ErrTaskRetryNotAllowed
		},
	}))
	defer server.Close()
	response := httptest.NewRecorder()
	server.Handler().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodPost, "/api/v1/tasks/task-1/retry", nil),
	)
	assertAPIError(t, response, http.StatusConflict, "task_not_retryable", false)
}

func TestResumeTaskMapsUnsafeResumeToStableConflict(t *testing.T) {
	server := New(time.Now(), WithTaskService(&stubTaskService{
		resume: func(context.Context, string) (download.Task, error) {
			return download.Task{}, download.ErrResumeNotSupported
		},
	}))
	defer server.Close()
	response := httptest.NewRecorder()
	server.Handler().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodPut, "/api/v1/tasks/task-1/resume", nil),
	)

	assertAPIError(t, response, http.StatusConflict, "resume_not_supported", false)
}

func TestWriteSSEEventUsesNamedJSONEvent(t *testing.T) {
	response := httptest.NewRecorder()
	err := writeSSEEvent(response, download.TaskEvent{
		Type: download.TaskUpdatedEvent,
		Task: download.Task{ID: "task-1", State: download.TaskStateDownloading},
	})
	if err != nil {
		t.Fatal(err)
	}
	value := response.Body.String()
	if !bytes.Contains([]byte(value), []byte("event: task.updated\n")) ||
		!bytes.Contains([]byte(value), []byte(`"id":"task-1"`)) {
		t.Fatalf("SSE = %q", value)
	}
}

func TestTaskAPICompletesRealSingleConnectionDownload(t *testing.T) {
	payload := bytes.Repeat([]byte("downpeed-api"), 4096)
	remote := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Length", fmt.Sprint(len(payload)))
		_, _ = w.Write(payload)
	}))
	defer remote.Close()
	server := New(time.Now())
	defer server.Close()
	directory := t.TempDir()
	body, err := json.Marshal(download.CreateTaskRequest{
		URL:           remote.URL + "/payload.bin",
		FileName:      "payload.bin",
		SaveDirectory: directory,
	})
	if err != nil {
		t.Fatal(err)
	}
	createdResponse := httptest.NewRecorder()
	server.Handler().ServeHTTP(
		createdResponse,
		httptest.NewRequest(http.MethodPost, "/api/v1/tasks", bytes.NewReader(body)),
	)
	if createdResponse.Code != http.StatusCreated {
		t.Fatalf("create status = %d, body = %s", createdResponse.Code, createdResponse.Body.String())
	}
	var created api.Envelope[download.Task]
	if err = json.NewDecoder(createdResponse.Body).Decode(&created); err != nil {
		t.Fatal(err)
	}

	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		response := httptest.NewRecorder()
		server.Handler().ServeHTTP(
			response,
			httptest.NewRequest(http.MethodGet, "/api/v1/tasks/"+created.Data.ID, nil),
		)
		var current api.Envelope[download.Task]
		if err = json.NewDecoder(response.Body).Decode(&current); err != nil {
			t.Fatal(err)
		}
		if current.Data.State == download.TaskStateCompleted {
			written, readErr := os.ReadFile(filepath.Join(directory, "payload.bin"))
			if readErr != nil {
				t.Fatal(readErr)
			}
			if !bytes.Equal(written, payload) {
				t.Fatal("downloaded API file does not match payload")
			}
			return
		}
		time.Sleep(time.Millisecond)
	}
	t.Fatal("download task did not complete")
}

func TestTaskAPIReportsRemoteValidatorChangeWithoutRetry(t *testing.T) {
	var requests atomic.Int64
	remote := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests.Add(1)
		if got := r.Header.Get("If-Match"); got != `"release-v1"` {
			t.Errorf("If-Match = %q, want release-v1", got)
		}
		w.Header().Set("ETag", `"release-v2"`)
		w.WriteHeader(http.StatusPreconditionFailed)
	}))
	defer remote.Close()
	server := New(time.Now())
	defer server.Close()
	directory := t.TempDir()
	body, err := json.Marshal(download.CreateTaskRequest{
		URL: remote.URL + "/changed.bin", FileName: "changed.bin", SaveDirectory: directory,
		ETag: `"release-v1"`,
	})
	if err != nil {
		t.Fatal(err)
	}
	response := httptest.NewRecorder()
	server.Handler().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodPost, "/api/v1/tasks", bytes.NewReader(body)),
	)
	if response.Code != http.StatusCreated {
		t.Fatalf("create status = %d, body = %s", response.Code, response.Body.String())
	}
	var created api.Envelope[download.Task]
	if err = json.NewDecoder(response.Body).Decode(&created); err != nil {
		t.Fatal(err)
	}
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		current := getTaskFromAPI(t, server, created.Data.ID)
		if current.State == download.TaskStateFailed {
			if current.Error == nil || current.Error.Code != "remote_resource_changed" || current.Error.Retryable || current.RetryCount != 0 {
				t.Fatalf("failed task = %#v", current)
			}
			if requests.Load() != 1 {
				t.Fatalf("requests = %d, want 1", requests.Load())
			}
			if _, statErr := os.Stat(filepath.Join(directory, "changed.bin")); !errors.Is(statErr, os.ErrNotExist) {
				t.Fatalf("changed resource was published: %v", statErr)
			}
			return
		}
		time.Sleep(time.Millisecond)
	}
	t.Fatal("changed resource task did not fail")
}

func TestTaskAPIAutomaticallyRetriesTemporaryHTTPFailure(t *testing.T) {
	payload := bytes.Repeat([]byte("retry-api"), 4096)
	var requestMu sync.Mutex
	requests := 0
	remote := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		requestMu.Lock()
		requests++
		attempt := requests
		requestMu.Unlock()
		if attempt == 1 {
			w.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		w.Header().Set("Content-Length", fmt.Sprint(len(payload)))
		_, _ = w.Write(payload)
	}))
	defer remote.Close()
	manager := download.NewManager(
		context.Background(),
		httpprotocol.NewDownloader(remote.Client()),
		download.WithMaxConcurrentTasks(1),
		download.WithRetryPolicy(1, 10*time.Millisecond),
	)
	server := New(time.Now(), WithTaskService(manager))
	defer server.Close()
	directory := t.TempDir()
	body, err := json.Marshal(download.CreateTaskRequest{
		URL: remote.URL + "/retry.bin", FileName: "retry.bin", SaveDirectory: directory,
	})
	if err != nil {
		t.Fatal(err)
	}
	createdResponse := httptest.NewRecorder()
	server.Handler().ServeHTTP(
		createdResponse,
		httptest.NewRequest(http.MethodPost, "/api/v1/tasks", bytes.NewReader(body)),
	)
	if createdResponse.Code != http.StatusCreated {
		t.Fatalf("create status = %d, body = %s", createdResponse.Code, createdResponse.Body.String())
	}
	var created api.Envelope[download.Task]
	if err = json.NewDecoder(createdResponse.Body).Decode(&created); err != nil {
		t.Fatal(err)
	}
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		current := getTaskFromAPI(t, server, created.Data.ID)
		if current.State == download.TaskStateCompleted {
			requestMu.Lock()
			requestCount := requests
			requestMu.Unlock()
			if requestCount != 2 || current.RetryCount != 1 || current.NextRetryAt != nil {
				t.Fatalf("completed retry task = %#v, requests = %d", current, requestCount)
			}
			written, readErr := os.ReadFile(filepath.Join(directory, "retry.bin"))
			if readErr != nil || !bytes.Equal(written, payload) {
				t.Fatalf("retried file mismatch: size=%d error=%v", len(written), readErr)
			}
			return
		}
		time.Sleep(time.Millisecond)
	}
	t.Fatal("temporarily failed task did not complete after retry")
}

func TestTaskAPIPausesResumesAndCompletesRangeDownload(t *testing.T) {
	payload := bytes.Repeat([]byte("downpeed-range"), 64*1024)
	etag := `"range-v1"`
	rangeOffsets := make(chan int, 1)
	remote := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := 0
		if rangeHeader := r.Header.Get("Range"); rangeHeader != "" {
			if got := r.Header.Get("If-Range"); got != etag {
				t.Errorf("If-Range = %q, want %q", got, etag)
			}
			if _, err := fmt.Sscanf(rangeHeader, "bytes=%d-", &start); err != nil {
				t.Errorf("Range = %q: %v", rangeHeader, err)
				w.WriteHeader(http.StatusBadRequest)
				return
			}
			rangeOffsets <- start
			w.Header().Set(
				"Content-Range",
				fmt.Sprintf("bytes %d-%d/%d", start, len(payload)-1, len(payload)),
			)
			w.Header().Set("Content-Length", fmt.Sprint(len(payload)-start))
			w.WriteHeader(http.StatusPartialContent)
		} else {
			w.Header().Set("Content-Length", fmt.Sprint(len(payload)))
		}
		w.Header().Set("ETag", etag)
		flusher := w.(http.Flusher)
		for offset := start; offset < len(payload); offset += 4096 {
			end := offset + 4096
			if end > len(payload) {
				end = len(payload)
			}
			if _, err := w.Write(payload[offset:end]); err != nil {
				return
			}
			flusher.Flush()
			time.Sleep(time.Millisecond)
		}
	}))
	defer remote.Close()
	server := New(time.Now())
	defer server.Close()
	directory := t.TempDir()
	body, err := json.Marshal(download.CreateTaskRequest{
		URL:           remote.URL + "/range.bin",
		FileName:      "range.bin",
		SaveDirectory: directory,
		ETag:          etag,
	})
	if err != nil {
		t.Fatal(err)
	}
	createdResponse := httptest.NewRecorder()
	server.Handler().ServeHTTP(
		createdResponse,
		httptest.NewRequest(http.MethodPost, "/api/v1/tasks", bytes.NewReader(body)),
	)
	if createdResponse.Code != http.StatusCreated {
		t.Fatalf("create status = %d, body = %s", createdResponse.Code, createdResponse.Body.String())
	}
	var created api.Envelope[download.Task]
	if err = json.NewDecoder(createdResponse.Body).Decode(&created); err != nil {
		t.Fatal(err)
	}

	var current download.Task
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		current = getTaskFromAPI(t, server, created.Data.ID)
		if current.State == download.TaskStateDownloading && current.Downloaded > 0 {
			break
		}
		time.Sleep(2 * time.Millisecond)
	}
	if current.Downloaded == 0 {
		t.Fatal("download did not report progress before pause")
	}
	finalPath := filepath.Join(directory, "range.bin")
	workPath := filepath.Join(directory, ".range.bin.downpeed")
	if _, err = os.Stat(finalPath); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("final file became visible before completion: %v", err)
	}
	if info, statErr := os.Stat(workPath); statErr != nil || info.Size() == 0 {
		t.Fatalf("temporary file unavailable while downloading: info=%v error=%v", info, statErr)
	}
	pauseResponse := httptest.NewRecorder()
	server.Handler().ServeHTTP(
		pauseResponse,
		httptest.NewRequest(http.MethodPut, "/api/v1/tasks/"+created.Data.ID+"/pause", nil),
	)
	if pauseResponse.Code != http.StatusOK {
		t.Fatalf("pause status = %d, body = %s", pauseResponse.Code, pauseResponse.Body.String())
	}
	var paused api.Envelope[download.Task]
	if err = json.NewDecoder(pauseResponse.Body).Decode(&paused); err != nil {
		t.Fatal(err)
	}
	if paused.Data.State != download.TaskStatePaused || paused.Data.Downloaded <= 0 {
		t.Fatalf("paused task = %#v", paused.Data)
	}
	if _, err = os.Stat(finalPath); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("final file became visible while paused: %v", err)
	}
	if info, statErr := os.Stat(workPath); statErr != nil || info.Size() != paused.Data.Downloaded {
		t.Fatalf("paused temporary size: info=%v task=%d error=%v", info, paused.Data.Downloaded, statErr)
	}

	resumeResponse := httptest.NewRecorder()
	server.Handler().ServeHTTP(
		resumeResponse,
		httptest.NewRequest(http.MethodPut, "/api/v1/tasks/"+created.Data.ID+"/resume", nil),
	)
	if resumeResponse.Code != http.StatusOK {
		t.Fatalf("resume status = %d, body = %s", resumeResponse.Code, resumeResponse.Body.String())
	}
	select {
	case offset := <-rangeOffsets:
		if int64(offset) != paused.Data.Downloaded {
			t.Fatalf("Range offset = %d, paused downloaded = %d", offset, paused.Data.Downloaded)
		}
	case <-time.After(time.Second):
		t.Fatal("resume request did not use Range")
	}

	deadline = time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		current = getTaskFromAPI(t, server, created.Data.ID)
		if current.State == download.TaskStateCompleted {
			value, readErr := os.ReadFile(finalPath)
			if readErr != nil || !bytes.Equal(value, payload) {
				t.Fatalf("completed file mismatch: size=%d error=%v", len(value), readErr)
			}
			if _, statErr := os.Stat(workPath); !errors.Is(statErr, os.ErrNotExist) {
				t.Fatalf("temporary file still exists after completion: %v", statErr)
			}
			return
		}
		time.Sleep(2 * time.Millisecond)
	}
	t.Fatalf("resumed task did not complete: %#v", current)
}

func TestTaskAPIRestoresInterruptedDownloadAcrossEngineRestart(t *testing.T) {
	payload := bytes.Repeat([]byte("downpeed-restart"), 64*1024)
	etag := `"restart-v1"`
	rangeOffsets := make(chan int, 1)
	remote := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := 0
		if rangeHeader := r.Header.Get("Range"); rangeHeader != "" {
			if got := r.Header.Get("If-Range"); got != etag {
				t.Errorf("If-Range = %q, want %q", got, etag)
			}
			if _, err := fmt.Sscanf(rangeHeader, "bytes=%d-", &start); err != nil {
				t.Errorf("Range = %q: %v", rangeHeader, err)
				w.WriteHeader(http.StatusBadRequest)
				return
			}
			rangeOffsets <- start
			w.Header().Set("Content-Range", fmt.Sprintf("bytes %d-%d/%d", start, len(payload)-1, len(payload)))
			w.Header().Set("Content-Length", fmt.Sprint(len(payload)-start))
			w.WriteHeader(http.StatusPartialContent)
		} else {
			w.Header().Set("Content-Length", fmt.Sprint(len(payload)))
		}
		w.Header().Set("ETag", etag)
		flusher := w.(http.Flusher)
		for offset := start; offset < len(payload); offset += 4096 {
			end := offset + 4096
			if end > len(payload) {
				end = len(payload)
			}
			if _, err := w.Write(payload[offset:end]); err != nil {
				return
			}
			flusher.Flush()
			time.Sleep(time.Millisecond)
		}
	}))
	defer remote.Close()

	root := t.TempDir()
	directory := filepath.Join(root, "downloads")
	if err := os.Mkdir(directory, 0o755); err != nil {
		t.Fatal(err)
	}
	databasePath := filepath.Join(root, "data", "tasks.db")
	store, err := repository.OpenBoltTaskStore(databasePath)
	if err != nil {
		t.Fatal(err)
	}
	manager, err := download.NewPersistentManager(context.Background(), httpprotocol.NewDownloader(remote.Client()), store)
	if err != nil {
		t.Fatal(err)
	}
	firstEngine := New(time.Now(), WithTaskService(manager))
	body, _ := json.Marshal(download.CreateTaskRequest{
		URL: remote.URL + "/restart.bin", FileName: "restart.bin", SaveDirectory: directory,
		ETag: etag,
	})
	createdResponse := httptest.NewRecorder()
	firstEngine.Handler().ServeHTTP(
		createdResponse,
		httptest.NewRequest(http.MethodPost, "/api/v1/tasks", bytes.NewReader(body)),
	)
	if createdResponse.Code != http.StatusCreated {
		t.Fatalf("create status = %d, body = %s", createdResponse.Code, createdResponse.Body.String())
	}
	var created api.Envelope[download.Task]
	if err = json.NewDecoder(createdResponse.Body).Decode(&created); err != nil {
		t.Fatal(err)
	}
	deadline := time.Now().Add(3 * time.Second)
	var beforeRestart download.Task
	for time.Now().Before(deadline) {
		beforeRestart = getTaskFromAPI(t, firstEngine, created.Data.ID)
		if beforeRestart.Downloaded > 0 {
			break
		}
		time.Sleep(2 * time.Millisecond)
	}
	if beforeRestart.Downloaded == 0 {
		t.Fatal("download did not report progress before restart")
	}
	if err = firstEngine.Close(); err != nil {
		t.Fatal(err)
	}

	finalPath := filepath.Join(directory, "restart.bin")
	workPath := filepath.Join(directory, ".restart.bin.downpeed")
	if _, err = os.Stat(finalPath); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("final file exists after interrupted shutdown: %v", err)
	}
	partialInfo, err := os.Stat(workPath)
	if err != nil || partialInfo.Size() == 0 {
		t.Fatalf("partial file after shutdown: info=%v error=%v", partialInfo, err)
	}

	reopenedStore, err := repository.OpenBoltTaskStore(databasePath)
	if err != nil {
		t.Fatal(err)
	}
	restoredManager, err := download.NewPersistentManager(
		context.Background(),
		httpprotocol.NewDownloader(remote.Client()),
		reopenedStore,
	)
	if err != nil {
		t.Fatal(err)
	}
	secondEngine := New(time.Now(), WithTaskService(restoredManager))
	defer secondEngine.Close()
	restored := getTaskFromAPI(t, secondEngine, created.Data.ID)
	if restored.State != download.TaskStatePaused || restored.Downloaded != partialInfo.Size() {
		t.Fatalf("restored task = %#v, partial size = %d", restored, partialInfo.Size())
	}

	resumeResponse := httptest.NewRecorder()
	secondEngine.Handler().ServeHTTP(
		resumeResponse,
		httptest.NewRequest(http.MethodPut, "/api/v1/tasks/"+created.Data.ID+"/resume", nil),
	)
	if resumeResponse.Code != http.StatusOK {
		t.Fatalf("resume status = %d, body = %s", resumeResponse.Code, resumeResponse.Body.String())
	}
	select {
	case offset := <-rangeOffsets:
		if int64(offset) != restored.Downloaded {
			t.Fatalf("resume offset = %d, restored downloaded = %d", offset, restored.Downloaded)
		}
	case <-time.After(time.Second):
		t.Fatal("restored task did not send a Range request")
	}

	deadline = time.Now().Add(4 * time.Second)
	for time.Now().Before(deadline) {
		current := getTaskFromAPI(t, secondEngine, created.Data.ID)
		if current.State == download.TaskStateCompleted {
			value, readErr := os.ReadFile(finalPath)
			if readErr != nil || !bytes.Equal(value, payload) {
				t.Fatalf("restored completed file mismatch: size=%d error=%v", len(value), readErr)
			}
			return
		}
		time.Sleep(2 * time.Millisecond)
	}
	t.Fatal("restored task did not complete")
}

func TestTaskAPIRestoresSegmentedCheckpointsAcrossEngineRestart(t *testing.T) {
	payload := bytes.Repeat([]byte("restart-segment"), 320*1024)
	etag := `"segmented-v1"`
	var remoteMu sync.Mutex
	phase := 1
	resumedRanges := make([]string, 0, 4)
	remote := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var start, end int64
		if _, err := fmt.Sscanf(r.Header.Get("Range"), "bytes=%d-%d", &start, &end); err != nil || start < 0 || end < start || end >= int64(len(payload)) {
			t.Errorf("invalid segmented Range = %q", r.Header.Get("Range"))
			w.WriteHeader(http.StatusRequestedRangeNotSatisfiable)
			return
		}
		remoteMu.Lock()
		requestPhase := phase
		if requestPhase == 2 {
			resumedRanges = append(resumedRanges, r.Header.Get("Range"))
		}
		remoteMu.Unlock()
		if got := r.Header.Get("If-Range"); got != etag {
			t.Errorf("If-Range = %q, want %q", got, etag)
		}
		w.Header().Set("ETag", etag)
		w.Header().Set("Content-Range", fmt.Sprintf("bytes %d-%d/%d", start, end, len(payload)))
		w.Header().Set("Content-Length", fmt.Sprint(end-start+1))
		w.WriteHeader(http.StatusPartialContent)
		flusher := w.(http.Flusher)
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
	defer remote.Close()

	root := t.TempDir()
	directory := filepath.Join(root, "downloads")
	if err := os.Mkdir(directory, 0o755); err != nil {
		t.Fatal(err)
	}
	databasePath := filepath.Join(root, "data", "tasks.db")
	store, err := repository.OpenBoltTaskStore(databasePath)
	if err != nil {
		t.Fatal(err)
	}
	manager, err := download.NewPersistentManager(context.Background(), httpprotocol.NewDownloader(remote.Client()), store)
	if err != nil {
		t.Fatal(err)
	}
	firstEngine := New(time.Now(), WithTaskService(manager))
	body, _ := json.Marshal(download.CreateTaskRequest{
		URL: remote.URL + "/segmented.bin", FileName: "segmented.bin", SaveDirectory: directory,
		ExpectedSize: int64(len(payload)), AcceptRanges: true, ETag: etag,
	})
	createdResponse := httptest.NewRecorder()
	firstEngine.Handler().ServeHTTP(
		createdResponse,
		httptest.NewRequest(http.MethodPost, "/api/v1/tasks", bytes.NewReader(body)),
	)
	if createdResponse.Code != http.StatusCreated {
		t.Fatalf("create status = %d, body = %s", createdResponse.Code, createdResponse.Body.String())
	}
	var created api.Envelope[download.Task]
	if err = json.NewDecoder(createdResponse.Body).Decode(&created); err != nil {
		t.Fatal(err)
	}
	deadline := time.Now().Add(4 * time.Second)
	var beforeRestart download.Task
	for time.Now().Before(deadline) {
		beforeRestart = getTaskFromAPI(t, firstEngine, created.Data.ID)
		if beforeRestart.Downloaded > 0 {
			break
		}
		time.Sleep(2 * time.Millisecond)
	}
	if beforeRestart.Downloaded <= 0 || beforeRestart.Downloaded >= int64(len(payload)) {
		t.Fatalf("unexpected progress before restart: %#v", beforeRestart)
	}
	if err = firstEngine.Close(); err != nil {
		t.Fatal(err)
	}

	finalPath := filepath.Join(directory, "segmented.bin")
	workPath := filepath.Join(directory, ".segmented.bin.downpeed")
	if _, err = os.Stat(finalPath); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("segmented final file exists after shutdown: %v", err)
	}
	workInfo, err := os.Stat(workPath)
	if err != nil || workInfo.Size() != int64(len(payload)) {
		t.Fatalf("preallocated work file = %#v, error = %v", workInfo, err)
	}

	reopenedStore, err := repository.OpenBoltTaskStore(databasePath)
	if err != nil {
		t.Fatal(err)
	}
	records, err := reopenedStore.Load(context.Background())
	if err != nil || len(records) != 1 || records[0].Checkpoint == nil {
		t.Fatalf("persisted records = %#v, error = %v", records, err)
	}
	persistedCheckpoint := download.CloneTransferCheckpoint(records[0].Checkpoint)
	persistedDownloaded, err := download.ValidateTransferCheckpoint(persistedCheckpoint, int64(len(payload)))
	if err != nil || persistedDownloaded <= 0 || persistedDownloaded >= workInfo.Size() {
		t.Fatalf("persisted checkpoint downloaded = %d, work size = %d, error = %v", persistedDownloaded, workInfo.Size(), err)
	}
	expectedRanges := make([]string, 0, len(persistedCheckpoint.Segments))
	for _, segment := range persistedCheckpoint.Segments {
		if segment.Completed < segment.End-segment.Start+1 {
			expectedRanges = append(expectedRanges, fmt.Sprintf("bytes=%d-%d", segment.Start+segment.Completed, segment.End))
		}
	}

	restoredManager, err := download.NewPersistentManager(
		context.Background(),
		httpprotocol.NewDownloader(remote.Client()),
		reopenedStore,
	)
	if err != nil {
		t.Fatal(err)
	}
	secondEngine := New(time.Now(), WithTaskService(restoredManager))
	defer secondEngine.Close()
	restored := getTaskFromAPI(t, secondEngine, created.Data.ID)
	if restored.State != download.TaskStatePaused || restored.Downloaded != persistedDownloaded || restored.Downloaded == workInfo.Size() {
		t.Fatalf("restored segmented task = %#v, checkpoint downloaded = %d", restored, persistedDownloaded)
	}
	remoteMu.Lock()
	phase = 2
	remoteMu.Unlock()
	resumeResponse := httptest.NewRecorder()
	secondEngine.Handler().ServeHTTP(
		resumeResponse,
		httptest.NewRequest(http.MethodPut, "/api/v1/tasks/"+created.Data.ID+"/resume", nil),
	)
	if resumeResponse.Code != http.StatusOK {
		t.Fatalf("resume status = %d, body = %s", resumeResponse.Code, resumeResponse.Body.String())
	}
	deadline = time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		current := getTaskFromAPI(t, secondEngine, created.Data.ID)
		if current.State == download.TaskStateCompleted {
			written, readErr := os.ReadFile(finalPath)
			if readErr != nil || !bytes.Equal(written, payload) {
				t.Fatalf("restored segmented file mismatch: size=%d error=%v", len(written), readErr)
			}
			remoteMu.Lock()
			sort.Strings(resumedRanges)
			remoteMu.Unlock()
			sort.Strings(expectedRanges)
			if fmt.Sprint(resumedRanges) != fmt.Sprint(expectedRanges) {
				t.Fatalf("resumed ranges = %v, want %v", resumedRanges, expectedRanges)
			}
			completedRecords, loadErr := reopenedStore.Load(context.Background())
			if loadErr != nil || len(completedRecords) != 1 || completedRecords[0].Checkpoint != nil {
				t.Fatalf("completed persisted records = %#v, error = %v", completedRecords, loadErr)
			}
			return
		}
		time.Sleep(2 * time.Millisecond)
	}
	t.Fatal("restored segmented task did not complete")
}

func getTaskFromAPI(t *testing.T, server *Server, id string) download.Task {
	t.Helper()
	response := httptest.NewRecorder()
	server.Handler().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodGet, "/api/v1/tasks/"+id, nil),
	)
	if response.Code != http.StatusOK {
		t.Fatalf("get task status = %d, body = %s", response.Code, response.Body.String())
	}
	var envelope api.Envelope[download.Task]
	if err := json.NewDecoder(response.Body).Decode(&envelope); err != nil {
		t.Fatal(err)
	}
	return envelope.Data
}

type stubResolver struct {
	resolve func(context.Context, download.ResolveRequest) (download.Resolution, error)
}

type stubBTResolver struct {
	resolveMagnet  func(context.Context, string) (download.BTResolution, error)
	resolveTorrent func(context.Context, []byte) (download.BTResolution, error)
}

func (resolver *stubBTResolver) ResolveMagnet(ctx context.Context, value string) (download.BTResolution, error) {
	if resolver.resolveMagnet == nil {
		return download.BTResolution{}, errors.New("unexpected ResolveMagnet call")
	}
	return resolver.resolveMagnet(ctx, value)
}

func (resolver *stubBTResolver) ResolveTorrent(ctx context.Context, value []byte) (download.BTResolution, error) {
	if resolver.resolveTorrent == nil {
		return download.BTResolution{}, errors.New("unexpected ResolveTorrent call")
	}
	return resolver.resolveTorrent(ctx, value)
}

type stubTaskService struct {
	create      func(context.Context, download.CreateTaskRequest) (download.Task, error)
	createBT    func(context.Context, download.CreateBTTaskRequest) (download.Task, error)
	list        func(context.Context) ([]download.Task, error)
	get         func(context.Context, string) (download.Task, error)
	pause       func(context.Context, string) (download.Task, error)
	resume      func(context.Context, string) (download.Task, error)
	retry       func(context.Context, string) (download.Task, error)
	cancel      func(context.Context, string) (download.Task, error)
	delete      func(context.Context, string, bool) (download.DeleteTaskResult, error)
	diagnostics func(context.Context, string) (download.BTDiagnostics, error)
	events      chan download.TaskEvent
}

func (service *stubTaskService) CreateBT(ctx context.Context, input download.CreateBTTaskRequest) (download.Task, error) {
	if service.createBT == nil {
		return download.Task{}, download.ErrUnsupportedProtocol
	}
	return service.createBT(ctx, input)
}

func (service *stubTaskService) GetBTDiagnostics(ctx context.Context, id string) (download.BTDiagnostics, error) {
	if service.diagnostics == nil {
		return download.BTDiagnostics{}, download.ErrUnsupportedProtocol
	}
	return service.diagnostics(ctx, id)
}

func (service *stubTaskService) Pause(ctx context.Context, id string) (download.Task, error) {
	if service.pause == nil {
		return download.Task{}, errors.New("unexpected Pause call")
	}
	return service.pause(ctx, id)
}

func (service *stubTaskService) Resume(ctx context.Context, id string) (download.Task, error) {
	if service.resume == nil {
		return download.Task{}, errors.New("unexpected Resume call")
	}
	return service.resume(ctx, id)
}

func (service *stubTaskService) Retry(ctx context.Context, id string) (download.Task, error) {
	if service.retry == nil {
		return download.Task{}, errors.New("unexpected Retry call")
	}
	return service.retry(ctx, id)
}

func (service *stubTaskService) Create(ctx context.Context, input download.CreateTaskRequest) (download.Task, error) {
	if service.create == nil {
		return download.Task{}, errors.New("unexpected Create call")
	}
	return service.create(ctx, input)
}

func (service *stubTaskService) List(ctx context.Context) ([]download.Task, error) {
	if service.list == nil {
		return []download.Task{}, nil
	}
	return service.list(ctx)
}

func (service *stubTaskService) Get(ctx context.Context, id string) (download.Task, error) {
	if service.get == nil {
		return download.Task{}, errors.New("unexpected Get call")
	}
	return service.get(ctx, id)
}

func (service *stubTaskService) Cancel(ctx context.Context, id string) (download.Task, error) {
	if service.cancel == nil {
		return download.Task{}, errors.New("unexpected Cancel call")
	}
	return service.cancel(ctx, id)
}

func (service *stubTaskService) Delete(ctx context.Context, id string, deleteFile bool) (download.DeleteTaskResult, error) {
	if service.delete == nil {
		return download.DeleteTaskResult{}, errors.New("unexpected Delete call")
	}
	return service.delete(ctx, id, deleteFile)
}

func (service *stubTaskService) Subscribe(context.Context) <-chan download.TaskEvent {
	if service.events == nil {
		service.events = make(chan download.TaskEvent)
	}
	return service.events
}

func (resolver stubResolver) Resolve(ctx context.Context, input download.ResolveRequest) (download.Resolution, error) {
	if resolver.resolve == nil {
		return download.Resolution{}, download.ErrInvalidRequest
	}
	return resolver.resolve(ctx, input)
}

func assertAPIError(t *testing.T, response *httptest.ResponseRecorder, status int, code string, retryable bool) {
	t.Helper()
	if response.Code != status {
		t.Fatalf("status = %d, want %d; body = %s", response.Code, status, response.Body.String())
	}
	var envelope api.Envelope[any]
	if err := json.NewDecoder(response.Body).Decode(&envelope); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if envelope.Error == nil || envelope.Error.Code != code || envelope.Error.Retryable != retryable {
		t.Fatalf("error = %#v", envelope.Error)
	}
	if envelope.RequestID == "" {
		t.Fatal("request ID is empty")
	}
}
