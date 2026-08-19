package httpapi

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/wfu-work/downpeed-fluter/backend/internal/download"
	"github.com/wfu-work/downpeed-fluter/backend/pkg/api"
)

type updateSettingsRequest struct {
	DefaultDownloadDirectory string                       `json:"defaultDownloadDirectory"`
	FileConflictPolicy       *download.FileConflictPolicy `json:"fileConflictPolicy,omitempty"`
	Scheduler                *download.SchedulerSettings  `json:"scheduler,omitempty"`
	Proxy                    *download.ProxySettings      `json:"proxy,omitempty"`
	BitTorrent               *download.BTPolicySettings   `json:"bitTorrent,omitempty"`
}

type updateProxyCredentialRequest struct {
	Password string `json:"password"`
}

type proxyCredentialStatus struct {
	Configured bool `json:"configured"`
}

func (s *Server) getSettings(w http.ResponseWriter, r *http.Request) {
	settings, err := s.settings.GetSettings(r.Context())
	if err != nil {
		writeSettingsError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, api.Envelope[download.EngineSettings]{
		Data:      settings,
		RequestID: requestIDFrom(r),
	})
}

func (s *Server) updateSettings(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, maxResolveRequestBytes)
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	var input updateSettingsRequest
	if err := decoder.Decode(&input); err != nil {
		writeAPIError(w, r, http.StatusBadRequest, "invalid_settings", "The request body must contain valid engine settings.", false)
		return
	}
	if err := ensureJSONEnd(decoder); err != nil {
		writeAPIError(w, r, http.StatusBadRequest, "invalid_settings", "The request body must contain one settings object.", false)
		return
	}
	current, err := s.settings.GetSettings(r.Context())
	if err != nil {
		writeSettingsError(w, r, err)
		return
	}
	policy := current.BitTorrent
	if input.BitTorrent != nil {
		policy = *input.BitTorrent
	}
	scheduler := current.Scheduler
	if input.Scheduler != nil {
		scheduler = *input.Scheduler
	}
	proxySettings := current.Proxy
	if input.Proxy != nil {
		proxySettings = *input.Proxy
	}
	fileConflictPolicy := current.FileConflictPolicy
	if input.FileConflictPolicy != nil {
		fileConflictPolicy = *input.FileConflictPolicy
	}
	settings, err := s.settings.UpdateSettings(r.Context(), download.EngineSettings{
		DefaultDownloadDirectory: input.DefaultDownloadDirectory,
		FileConflictPolicy:       fileConflictPolicy,
		Scheduler:                scheduler,
		Proxy:                    proxySettings,
		BitTorrent:               policy,
	})
	if err != nil {
		writeSettingsError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, api.Envelope[download.EngineSettings]{
		Data:      settings,
		RequestID: requestIDFrom(r),
	})
}

func (s *Server) updateProxyCredential(w http.ResponseWriter, r *http.Request) {
	if s.proxy == nil {
		writeAPIError(w, r, http.StatusServiceUnavailable, "proxy_runtime_unavailable", "The proxy runtime is unavailable.", true)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxResolveRequestBytes)
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	var input updateProxyCredentialRequest
	if err := decoder.Decode(&input); err != nil {
		writeAPIError(w, r, http.StatusBadRequest, "invalid_proxy_credential", "The request body must contain a valid proxy credential.", false)
		return
	}
	if err := ensureJSONEnd(decoder); err != nil {
		writeAPIError(w, r, http.StatusBadRequest, "invalid_proxy_credential", "The request body must contain one proxy credential.", false)
		return
	}
	if err := s.proxy.SetPassword(input.Password); err != nil {
		writeAPIError(w, r, http.StatusBadRequest, "invalid_proxy_credential", "The proxy credential exceeds the supported limits.", false)
		return
	}
	writeJSON(w, http.StatusOK, api.Envelope[proxyCredentialStatus]{
		Data:      proxyCredentialStatus{Configured: input.Password != ""},
		RequestID: requestIDFrom(r),
	})
}

func (s *Server) testProxy(w http.ResponseWriter, r *http.Request) {
	if s.proxy == nil {
		writeAPIError(w, r, http.StatusServiceUnavailable, "proxy_runtime_unavailable", "The proxy runtime is unavailable.", true)
		return
	}
	result, err := s.proxy.Test(r.Context())
	if err != nil {
		switch {
		case errors.Is(err, download.ErrProxyAuthenticationFailed):
			writeAPIError(w, r, http.StatusBadGateway, "proxy_authentication_failed", "The proxy rejected the configured credentials.", false)
		case errors.Is(err, download.ErrProxyTestTimeout):
			writeAPIError(w, r, http.StatusGatewayTimeout, "proxy_test_timeout", "The proxy test did not complete in time.", true)
		default:
			writeAPIError(w, r, http.StatusBadGateway, "proxy_connection_failed", "The configured connection route could not reach the test service.", true)
		}
		return
	}
	writeJSON(w, http.StatusOK, api.Envelope[download.ProxyTestResult]{
		Data:      result,
		RequestID: requestIDFrom(r),
	})
}

func writeSettingsError(w http.ResponseWriter, r *http.Request, err error) {
	if errors.Is(err, download.ErrInvalidFileConflictPolicy) {
		writeAPIError(w, r, http.StatusBadRequest, "invalid_file_conflict_policy", "File conflict handling must use a supported safe policy.", false)
		return
	}
	if errors.Is(err, download.ErrInvalidSchedulerSettings) {
		writeAPIError(w, r, http.StatusBadRequest, "invalid_scheduler_settings", "Scheduler settings exceed the supported operating limits.", false)
		return
	}
	if errors.Is(err, download.ErrInvalidBTPolicy) {
		writeAPIError(w, r, http.StatusBadRequest, "invalid_bt_policy", "BitTorrent policy exceeds the current safe operating limits.", false)
		return
	}
	if errors.Is(err, download.ErrInvalidProxySettings) {
		writeAPIError(w, r, http.StatusBadRequest, "invalid_proxy_settings", "Proxy settings exceed the supported operating limits.", false)
		return
	}
	if errors.Is(err, download.ErrInvalidSettings) {
		writeAPIError(w, r, http.StatusBadRequest, "invalid_download_directory", "Select an existing absolute download directory.", false)
		return
	}
	writeAPIError(w, r, http.StatusInternalServerError, "settings_operation_failed", "The engine could not update its settings.", true)
}
