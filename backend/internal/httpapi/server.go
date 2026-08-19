package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"runtime"
	"strconv"
	"sync/atomic"
	"time"

	"github.com/wfu-work/downpeed-fluter/backend/internal/buildinfo"
	enginediagnostics "github.com/wfu-work/downpeed-fluter/backend/internal/diagnostics"
	"github.com/wfu-work/downpeed-fluter/backend/internal/download"
	btprotocol "github.com/wfu-work/downpeed-fluter/backend/internal/protocol/bt"
	httpprotocol "github.com/wfu-work/downpeed-fluter/backend/internal/protocol/http"
	"github.com/wfu-work/downpeed-fluter/backend/pkg/api"
)

const (
	maxResolveRequestBytes = 64 << 10
	maxBatchRequestBytes   = 512 << 10
	maxBatchTasks          = 100
)

type Server struct {
	startedAt     time.Time
	requests      atomic.Uint64
	resolver      download.Resolver
	btResolver    download.BTResolver
	btTasks       download.BTTaskCreator
	btDiagnostics download.BTDiagnosticsService
	tasks         download.TaskService
	settings      download.SettingsService
	proxy         download.ProxyService
	diagnostics   enginediagnostics.Provider
	closer        interface{ Close() error }
	handler       http.Handler
}

type Option func(*Server)

func WithResolver(resolver download.Resolver) Option {
	return func(server *Server) {
		if resolver != nil {
			server.resolver = resolver
		}
	}
}

func WithTaskService(tasks download.TaskService) Option {
	return func(server *Server) {
		if tasks == nil {
			return
		}
		server.tasks = tasks
		if creator, ok := tasks.(download.BTTaskCreator); ok {
			server.btTasks = creator
		}
		if diagnostics, ok := tasks.(download.BTDiagnosticsService); ok {
			server.btDiagnostics = diagnostics
		}
		server.closer = nil
		if closer, ok := tasks.(interface{ Close() error }); ok {
			server.closer = closer
		}
	}
}

func WithBTResolver(resolver download.BTResolver) Option {
	return func(server *Server) {
		if resolver != nil {
			server.btResolver = resolver
		}
	}
}

func WithSettingsService(settings download.SettingsService) Option {
	return func(server *Server) {
		if settings != nil {
			server.settings = settings
		}
	}
}

func WithProxyService(proxy download.ProxyService) Option {
	return func(server *Server) {
		if proxy != nil {
			server.proxy = proxy
		}
	}
}

func WithDiagnosticsService(diagnostics enginediagnostics.Provider) Option {
	return func(server *Server) {
		if diagnostics != nil {
			server.diagnostics = diagnostics
		}
	}
}

type Health struct {
	Status     string `json:"status"`
	APIVersion string `json:"apiVersion"`
	Version    string `json:"version"`
}

type Info struct {
	Name       string    `json:"name"`
	Version    string    `json:"version"`
	Commit     string    `json:"commit"`
	BuildDate  string    `json:"buildDate"`
	APIVersion string    `json:"apiVersion"`
	GoVersion  string    `json:"goVersion"`
	OS         string    `json:"os"`
	Arch       string    `json:"arch"`
	StartedAt  time.Time `json:"startedAt"`
	UptimeMS   int64     `json:"uptimeMs"`
}

func New(startedAt time.Time, options ...Option) *Server {
	settings, _ := download.NewSettingsManager(
		context.Background(),
		nil,
		os.TempDir(),
	)
	server := &Server{
		startedAt:  startedAt.UTC(),
		resolver:   httpprotocol.NewResolver(nil),
		btResolver: btprotocol.NewResolver(),
		settings:   settings,
	}
	for _, option := range options {
		option(server)
	}
	if server.tasks == nil {
		manager := download.NewManager(context.Background(), httpprotocol.NewDownloader(nil))
		server.tasks = manager
		server.closer = manager
	}
	if server.diagnostics == nil {
		server.diagnostics = enginediagnostics.New(enginediagnostics.Config{
			DataDirectory: os.TempDir(),
			StartedAt:     startedAt,
		}, server.tasks, server.settings)
	}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/v1/health", server.health)
	mux.HandleFunc("GET /api/v1/info", server.info)
	mux.HandleFunc("GET /api/v1/diagnostics", server.getDiagnostics)
	mux.HandleFunc("POST /api/v1/diagnostics/export", server.exportDiagnostics)
	mux.HandleFunc("GET /api/v1/settings", server.getSettings)
	mux.HandleFunc("PUT /api/v1/settings", server.updateSettings)
	mux.HandleFunc("PUT /api/v1/settings/proxy/credential", server.updateProxyCredential)
	mux.HandleFunc("POST /api/v1/settings/proxy/test", server.testProxy)
	mux.HandleFunc("POST /api/v1/tasks/resolve", server.resolveDownload)
	mux.HandleFunc("POST /api/v1/bt/resolve/magnet", server.resolveMagnet)
	mux.HandleFunc("POST /api/v1/bt/resolve/torrent", server.resolveTorrent)
	mux.HandleFunc("POST /api/v1/bt/tasks", server.createBTTask)
	mux.HandleFunc("GET /api/v1/tasks/{id}/bt/diagnostics", server.getBTDiagnostics)
	mux.HandleFunc("POST /api/v1/tasks", server.createTask)
	mux.HandleFunc("POST /api/v1/tasks/batch", server.createTasksBatch)
	mux.HandleFunc("POST /api/v1/tasks/batch/actions", server.actOnTasksBatch)
	mux.HandleFunc("POST /api/v1/tasks/batch/delete", server.deleteTasksBatch)
	mux.HandleFunc("GET /api/v1/tasks", server.listTasks)
	mux.HandleFunc("GET /api/v1/tasks/{id}", server.getTask)
	mux.HandleFunc("PUT /api/v1/tasks/{id}/pause", server.pauseTask)
	mux.HandleFunc("PUT /api/v1/tasks/{id}/resume", server.resumeTask)
	mux.HandleFunc("POST /api/v1/tasks/{id}/retry", server.retryTask)
	mux.HandleFunc("PUT /api/v1/tasks/{id}/cancel", server.cancelTask)
	mux.HandleFunc("DELETE /api/v1/tasks/completed", server.deleteCompletedTasks)
	mux.HandleFunc("DELETE /api/v1/tasks/{id}/record", server.deleteTask)
	// Kept for API v1 compatibility. New clients use PUT /cancel.
	mux.HandleFunc("DELETE /api/v1/tasks/{id}", server.cancelTask)
	mux.HandleFunc("GET /api/v1/events", server.events)
	server.handler = server.withRequestContext(server.withRecovery(mux))
	return server
}

func (s *Server) Close() error {
	if s.closer != nil {
		return s.closer.Close()
	}
	return nil
}

func (s *Server) resolveDownload(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, maxResolveRequestBytes)
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()

	var input download.ResolveRequest
	if err := decoder.Decode(&input); err != nil {
		writeAPIError(w, r, http.StatusBadRequest, "invalid_request", "The request body must contain a valid download URL.", false)
		return
	}
	if err := ensureJSONEnd(decoder); err != nil {
		writeAPIError(w, r, http.StatusBadRequest, "invalid_request", "The request body must contain one JSON object.", false)
		return
	}

	resolution, err := s.resolver.Resolve(r.Context(), input)
	if err != nil {
		switch {
		case errors.Is(err, download.ErrInvalidRequest):
			writeAPIError(w, r, http.StatusBadRequest, "invalid_request", "Enter a valid absolute download URL.", false)
		case errors.Is(err, download.ErrUnsupportedScheme):
			writeAPIError(w, r, http.StatusBadRequest, "unsupported_scheme", "Only HTTP and HTTPS download URLs are supported.", false)
		case errors.Is(err, context.DeadlineExceeded):
			writeAPIError(w, r, http.StatusGatewayTimeout, "resolve_failed", "The remote server did not respond in time.", true)
		default:
			writeAPIError(w, r, http.StatusBadGateway, "resolve_failed", "The remote download could not be inspected.", true)
		}
		return
	}

	writeJSON(w, http.StatusOK, api.Envelope[download.Resolution]{
		Data:      resolution,
		RequestID: requestIDFrom(r),
	})
}

func ensureJSONEnd(decoder *json.Decoder) error {
	var extra any
	if err := decoder.Decode(&extra); !errors.Is(err, io.EOF) {
		if err == nil {
			return errors.New("multiple JSON values")
		}
		return err
	}
	return nil
}

func writeAPIError(w http.ResponseWriter, r *http.Request, status int, code, message string, retryable bool) {
	writeJSON(w, status, api.Envelope[any]{
		Error: &api.Error{
			Code:      code,
			Message:   message,
			Retryable: retryable,
		},
		RequestID: requestIDFrom(r),
	})
}

func (s *Server) Handler() http.Handler {
	return s.handler
}

func (s *Server) health(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, api.Envelope[Health]{
		Data: Health{
			Status:     "ok",
			APIVersion: buildinfo.APIVersion,
			Version:    buildinfo.Version,
		},
		RequestID: requestIDFrom(r),
	})
}

func (s *Server) info(w http.ResponseWriter, r *http.Request) {
	uptime := time.Since(s.startedAt)
	if uptime < 0 {
		uptime = 0
	}
	writeJSON(w, http.StatusOK, api.Envelope[Info]{
		Data: Info{
			Name:       "Downpeed Engine",
			Version:    buildinfo.Version,
			Commit:     buildinfo.Commit,
			BuildDate:  buildinfo.Date,
			APIVersion: buildinfo.APIVersion,
			GoVersion:  runtime.Version(),
			OS:         runtime.GOOS,
			Arch:       runtime.GOARCH,
			StartedAt:  s.startedAt,
			UptimeMS:   uptime.Milliseconds(),
		},
		RequestID: requestIDFrom(r),
	})
}

func (s *Server) withRequestContext(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requestID := r.Header.Get("X-Request-ID")
		if requestID == "" {
			sequence := s.requests.Add(1)
			requestID = strconv.FormatInt(time.Now().UTC().UnixMilli(), 36) + "-" + strconv.FormatUint(sequence, 36)
		}
		w.Header().Set("X-Request-ID", requestID)
		next.ServeHTTP(w, r.WithContext(withRequestID(r.Context(), requestID)))
	})
}

func (s *Server) withRecovery(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if recovered := recover(); recovered != nil {
				writeJSON(w, http.StatusInternalServerError, api.Envelope[any]{
					Error: &api.Error{
						Code:      "internal_error",
						Message:   "The engine could not complete this request.",
						Retryable: true,
					},
					RequestID: requestIDFrom(r),
				})
			}
		}()
		next.ServeHTTP(w, r)
	})
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(value); err != nil {
		panic(fmt.Errorf("encode JSON response: %w", err))
	}
}
