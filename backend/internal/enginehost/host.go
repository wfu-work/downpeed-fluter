package enginehost

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/wfu-work/downpeed-fluter/backend/internal/app"
	"github.com/wfu-work/downpeed-fluter/backend/internal/config"
)

const startupTimeout = 10 * time.Second

type State int

const (
	StateStopped State = iota
	StateStarting
	StateRunning
	StateStopping
)

type startConfig struct {
	Address                  *string `json:"address"`
	DataDir                  *string `json:"dataDir"`
	DefaultDownloadDirectory *string `json:"defaultDownloadDirectory"`
	MaxConcurrentTasks       *int    `json:"maxConcurrentTasks"`
	MaxRetries               *int    `json:"maxRetries"`
	RetryBaseDelayMS         *int64  `json:"retryBaseDelayMs"`
	DownloadRateLimit        *int64  `json:"downloadRateLimit"`
}

// Host owns one in-process Downpeed engine. It deliberately exposes only
// lifecycle state; task data remains behind the versioned HTTP/SSE API.
type Host struct {
	mu        sync.Mutex
	state     State
	cancel    context.CancelFunc
	done      chan struct{}
	startDone chan struct{}
	started   bool
	runErr    error
	lastError string
	address   string
	logger    *slog.Logger
}

func New() *Host {
	return &Host{
		logger: slog.New(slog.NewTextHandler(io.Discard, nil)),
	}
}

func (h *Host) Start(configJSON string) error {
	cfg, err := decodeConfig(configJSON)
	if err != nil {
		h.setLastError(err.Error())
		return err
	}

	for {
		h.mu.Lock()
		switch h.state {
		case StateRunning:
			h.lastError = ""
			h.mu.Unlock()
			return nil
		case StateStarting:
			startDone := h.startDone
			h.mu.Unlock()
			<-startDone
			if h.State() == StateRunning {
				return nil
			}
			if err := h.currentRunError(); err != nil {
				return err
			}
			return errors.New("The embedded Downpeed engine stopped before it became ready.")
		case StateStopping:
			done := h.done
			h.mu.Unlock()
			<-done
			continue
		case StateStopped:
			ctx, cancel := context.WithCancel(context.Background())
			h.state = StateStarting
			h.cancel = cancel
			h.done = make(chan struct{})
			h.startDone = make(chan struct{})
			h.started = false
			h.runErr = nil
			h.lastError = ""
			h.address = ""
			done := h.done
			startDone := h.startDone
			h.mu.Unlock()

			h.run(ctx, cfg)
			timer := time.NewTimer(startupTimeout)
			defer timer.Stop()
			select {
			case <-startDone:
				if h.State() == StateRunning {
					return nil
				}
				if err := h.currentRunError(); err != nil {
					return err
				}
				return errors.New("The embedded Downpeed engine stopped before it became ready.")
			case <-timer.C:
				cancel()
				<-done
				timeoutErr := errors.New("The embedded Downpeed engine timed out while starting.")
				h.setLastError(timeoutErr.Error())
				return timeoutErr
			}
		}
	}
}

func (h *Host) run(ctx context.Context, cfg config.Config) {
	go func() {
		var readyOnce sync.Once
		err := app.New(cfg, h.logger).RunWithReady(ctx, func(address string) {
			readyOnce.Do(func() {
				h.mu.Lock()
				if h.state == StateStarting && !h.started {
					h.state = StateRunning
					h.address = address
					h.started = true
					close(h.startDone)
				}
				h.mu.Unlock()
			})
		})

		h.mu.Lock()
		wasStarting := h.state == StateStarting
		if wasStarting && err == nil {
			err = errors.New("engine stopped before listener initialization")
		}
		h.runErr = err
		if err != nil {
			h.lastError = publicEngineError(err)
		}
		if !h.started {
			h.started = true
			close(h.startDone)
		}
		h.state = StateStopped
		h.cancel = nil
		h.address = ""
		close(h.done)
		h.mu.Unlock()
	}()
}

func (h *Host) Stop() error {
	for {
		h.mu.Lock()
		switch h.state {
		case StateStopped:
			h.mu.Unlock()
			return nil
		case StateStopping:
			done := h.done
			h.mu.Unlock()
			<-done
			return h.currentRunError()
		case StateStarting, StateRunning:
			h.state = StateStopping
			cancel := h.cancel
			done := h.done
			h.mu.Unlock()
			cancel()
			<-done
			return h.currentRunError()
		}
	}
}

func (h *Host) State() State {
	h.mu.Lock()
	defer h.mu.Unlock()
	return h.state
}

func (h *Host) Address() string {
	h.mu.Lock()
	defer h.mu.Unlock()
	return h.address
}

func (h *Host) LastError() string {
	h.mu.Lock()
	defer h.mu.Unlock()
	return h.lastError
}

func (h *Host) currentRunError() error {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.runErr != nil {
		return errors.New(h.lastError)
	}
	if h.lastError != "" {
		return errors.New(h.lastError)
	}
	return nil
}

func (h *Host) setLastError(message string) {
	h.mu.Lock()
	h.lastError = message
	h.mu.Unlock()
}

func decodeConfig(value string) (config.Config, error) {
	cfg, err := config.Parse(nil, io.Discard)
	if err != nil {
		return config.Config{}, errors.New("The embedded Downpeed engine configuration is unavailable.")
	}
	value = strings.TrimSpace(value)
	if value == "" {
		value = "{}"
	}
	if len(value) > 64<<10 {
		return config.Config{}, errors.New("The embedded Downpeed engine configuration is too large.")
	}
	decoder := json.NewDecoder(bytes.NewBufferString(value))
	decoder.DisallowUnknownFields()
	var input startConfig
	if err = decoder.Decode(&input); err != nil {
		return config.Config{}, errors.New("The embedded Downpeed engine configuration is invalid.")
	}
	if err = ensureJSONEnd(decoder); err != nil {
		return config.Config{}, errors.New("The embedded Downpeed engine configuration must contain one JSON object.")
	}
	if input.Address != nil {
		cfg.Address = strings.TrimSpace(*input.Address)
	}
	if input.DataDir != nil {
		cfg.DataDir = strings.TrimSpace(*input.DataDir)
	}
	if input.DefaultDownloadDirectory != nil {
		cfg.DefaultDownloadDirectory = strings.TrimSpace(*input.DefaultDownloadDirectory)
	}
	if input.MaxConcurrentTasks != nil {
		cfg.MaxConcurrentTasks = *input.MaxConcurrentTasks
	}
	if input.MaxRetries != nil {
		cfg.MaxRetries = *input.MaxRetries
	}
	if input.RetryBaseDelayMS != nil {
		cfg.RetryBaseDelay = time.Duration(*input.RetryBaseDelayMS) * time.Millisecond
	}
	if input.DownloadRateLimit != nil {
		cfg.DownloadRateLimit = *input.DownloadRateLimit
	}
	// The in-process ABI intentionally has no allowRemote escape hatch.
	cfg.AllowRemote = false
	if err = cfg.Validate(); err != nil {
		return config.Config{}, fmt.Errorf("invalid embedded engine configuration: %w", err)
	}
	return cfg, nil
}

func ensureJSONEnd(decoder *json.Decoder) error {
	var extra any
	if err := decoder.Decode(&extra); !errors.Is(err, io.EOF) {
		if err == nil {
			return errors.New("extra JSON value")
		}
		return err
	}
	return nil
}

func publicEngineError(err error) string {
	var networkError *net.OpError
	switch {
	case errors.As(err, &networkError):
		return "The local Downpeed engine address is already in use or unavailable."
	case errors.Is(err, os.ErrPermission):
		return "Downpeed cannot access its local data or download directory."
	default:
		return "The embedded Downpeed engine could not start."
	}
}
