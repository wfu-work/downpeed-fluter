package httpapi

import (
	"net/http"
	"strconv"

	enginediagnostics "github.com/wfu-work/downpeed-fluter/backend/internal/diagnostics"
	"github.com/wfu-work/downpeed-fluter/backend/pkg/api"
)

func (s *Server) getDiagnostics(w http.ResponseWriter, r *http.Request) {
	snapshot, err := s.diagnostics.Snapshot(r.Context())
	if err != nil {
		writeDiagnosticsError(w, r)
		return
	}
	writeJSON(w, http.StatusOK, api.Envelope[enginediagnostics.Snapshot]{
		Data:      snapshot,
		RequestID: requestIDFrom(r),
	})
}

func (s *Server) exportDiagnostics(w http.ResponseWriter, r *http.Request) {
	archive, err := s.diagnostics.Export(r.Context())
	if err != nil {
		writeDiagnosticsError(w, r)
		return
	}
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Content-Disposition", `attachment; filename="`+archive.Filename+`"`)
	w.Header().Set("Content-Type", "application/zip")
	w.Header().Set("Content-Length", strconv.Itoa(len(archive.Bytes)))
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("X-Downpeed-Filename", archive.Filename)
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(archive.Bytes)
}

func writeDiagnosticsError(w http.ResponseWriter, r *http.Request) {
	writeAPIError(w, r, http.StatusServiceUnavailable, "diagnostics_unavailable", "The engine could not prepare diagnostic information.", true)
}
