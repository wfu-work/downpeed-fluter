package httpapi

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"net/http"

	"github.com/wfu-work/downpeed-fluter/backend/internal/download"
	"github.com/wfu-work/downpeed-fluter/backend/pkg/api"
)

type createBTTaskRequest struct {
	Metadata            string   `json:"metadata"`
	SaveDirectory       string   `json:"saveDirectory"`
	SelectedFileIndexes []int    `json:"selectedFileIndexes"`
	ExplicitPeers       []string `json:"explicitPeers"`
}

func (s *Server) createBTTask(w http.ResponseWriter, r *http.Request) {
	if s.btTasks == nil {
		writeAPIError(w, r, http.StatusNotImplemented, "bt_transfer_unavailable", "BT transfer is not enabled in this engine.", false)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, download.MaxTorrentMetadataBytes*2)
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	var input createBTTaskRequest
	if err := decoder.Decode(&input); err != nil || ensureJSONEnd(decoder) != nil {
		writeAPIError(w, r, http.StatusBadRequest, "invalid_request", "The request body must contain a valid BT task.", false)
		return
	}
	metadata, err := base64.StdEncoding.DecodeString(input.Metadata)
	if err != nil || len(metadata) == 0 || len(metadata) > download.MaxTorrentMetadataBytes {
		writeAPIError(w, r, http.StatusBadRequest, "bt_metadata_invalid", "The Torrent metadata is malformed or unsupported.", false)
		return
	}
	task, err := s.btTasks.CreateBT(r.Context(), download.CreateBTTaskRequest{
		Metadata: metadata, SaveDirectory: input.SaveDirectory,
		SelectedFileIndexes: input.SelectedFileIndexes, ExplicitPeers: input.ExplicitPeers,
	})
	if err != nil {
		writeTaskServiceError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, api.Envelope[download.Task]{Data: task, RequestID: requestIDFrom(r)})
}

func (s *Server) getBTDiagnostics(w http.ResponseWriter, r *http.Request) {
	if s.btDiagnostics == nil {
		writeAPIError(w, r, http.StatusNotImplemented, "bt_diagnostics_unavailable", "BT connection diagnostics are not available in this engine.", false)
		return
	}
	diagnostics, err := s.btDiagnostics.GetBTDiagnostics(r.Context(), r.PathValue("id"))
	if err != nil {
		switch {
		case errors.Is(err, download.ErrTaskNotFound):
			writeAPIError(w, r, http.StatusNotFound, "task_not_found", "The download task does not exist.", false)
		case errors.Is(err, download.ErrUnsupportedProtocol):
			writeAPIError(w, r, http.StatusConflict, "bt_diagnostics_not_applicable", "Connection diagnostics are only available for BitTorrent tasks.", false)
		default:
			writeAPIError(w, r, http.StatusInternalServerError, "bt_diagnostics_failed", "BT connection diagnostics could not be loaded.", true)
		}
		return
	}
	writeJSON(w, http.StatusOK, api.Envelope[download.BTDiagnostics]{
		Data:      diagnostics,
		RequestID: requestIDFrom(r),
	})
}

type resolveMagnetRequest struct {
	Magnet string `json:"magnet"`
}

func (s *Server) resolveMagnet(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, download.MaxMagnetURIBytes+1024)
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	var input resolveMagnetRequest
	if err := decoder.Decode(&input); err != nil || ensureJSONEnd(decoder) != nil {
		writeAPIError(w, r, http.StatusBadRequest, "bt_invalid_magnet", "Enter a valid Magnet URI.", false)
		return
	}
	resolution, err := s.btResolver.ResolveMagnet(r.Context(), input.Magnet)
	if err != nil {
		writeBTResolveError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, api.Envelope[download.BTResolution]{
		Data: resolution, RequestID: requestIDFrom(r),
	})
}

func (s *Server) resolveTorrent(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, download.MaxTorrentMetadataBytes+1)
	data, err := io.ReadAll(r.Body)
	if err != nil {
		var maxBytesError *http.MaxBytesError
		if errors.As(err, &maxBytesError) {
			writeBTResolveError(w, r, download.ErrBTMetadataTooLarge)
			return
		}
		writeAPIError(w, r, http.StatusBadRequest, "bt_metadata_invalid", "The Torrent metadata could not be read.", false)
		return
	}
	resolution, err := s.btResolver.ResolveTorrent(r.Context(), data)
	if err != nil {
		writeBTResolveError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, api.Envelope[download.BTResolution]{
		Data: resolution, RequestID: requestIDFrom(r),
	})
}

func writeBTResolveError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, download.ErrBTInvalidMagnet):
		writeAPIError(w, r, http.StatusBadRequest, "bt_invalid_magnet", "Enter a valid Magnet URI with a supported InfoHash.", false)
	case errors.Is(err, download.ErrBTMetadataTooLarge):
		writeAPIError(w, r, http.StatusRequestEntityTooLarge, "bt_metadata_too_large", "Torrent metadata cannot exceed 8 MiB.", false)
	case errors.Is(err, download.ErrBTPathUnsafe):
		writeAPIError(w, r, http.StatusBadRequest, "bt_path_unsafe", "Torrent metadata contains an unsafe or conflicting file path.", false)
	case errors.Is(err, download.ErrBTFileLimit):
		writeAPIError(w, r, http.StatusBadRequest, "bt_file_limit", "Torrent metadata contains too many files.", false)
	case errors.Is(err, download.ErrBTSizeLimit):
		writeAPIError(w, r, http.StatusBadRequest, "bt_size_limit", "Torrent metadata declares more data than Downpeed can safely handle.", false)
	case errors.Is(err, download.ErrBTTrackerInvalid):
		writeAPIError(w, r, http.StatusBadRequest, "bt_tracker_invalid", "Torrent metadata contains an unsupported Tracker address.", false)
	default:
		writeAPIError(w, r, http.StatusBadRequest, "bt_metadata_invalid", "The Torrent metadata is malformed or unsupported.", false)
	}
}
