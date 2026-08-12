package app

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/wfu-work/downpeed-fluter/backend/internal/config"
	"github.com/wfu-work/downpeed-fluter/backend/internal/download"
	"github.com/wfu-work/downpeed-fluter/backend/internal/httpapi"
	btprotocol "github.com/wfu-work/downpeed-fluter/backend/internal/protocol/bt"
	httpprotocol "github.com/wfu-work/downpeed-fluter/backend/internal/protocol/http"
	"github.com/wfu-work/downpeed-fluter/backend/internal/repository"
)

type App struct {
	cfg    config.Config
	logger *slog.Logger
}

func New(cfg config.Config, logger *slog.Logger) *App {
	return &App{cfg: cfg, logger: logger}
}

func (a *App) Run(ctx context.Context) error {
	return a.RunWithReady(ctx, nil)
}

// RunWithReady runs the engine until ctx is cancelled. The optional ready
// callback is invoked exactly once after the HTTP listener has been created,
// so in-process hosts can distinguish a usable engine from a goroutine that
// merely started initialization.
func (a *App) RunWithReady(ctx context.Context, ready func(address string)) error {
	defaultDownloadDirectory := a.cfg.DefaultDownloadDirectory
	if defaultDownloadDirectory == "" {
		userHomeDir, err := os.UserHomeDir()
		if err != nil {
			return fmt.Errorf("resolve user home directory: %w", err)
		}
		defaultDownloadDirectory = filepath.Join(userHomeDir, "Downloads")
	}
	if err := ensureDefaultDownloadDirectory(defaultDownloadDirectory); err != nil {
		return err
	}
	store, err := repository.OpenBoltTaskStore(filepath.Join(a.cfg.DataDir, "tasks.db"))
	if err != nil {
		return err
	}
	settings, err := download.NewSettingsManager(
		context.Background(),
		store,
		defaultDownloadDirectory,
	)
	if err != nil {
		_ = store.Close()
		return err
	}
	manager, err := download.NewPersistentManager(
		context.Background(),
		httpprotocol.NewDownloader(nil),
		store,
		download.WithMaxConcurrentTasks(a.cfg.MaxConcurrentTasks),
		download.WithRetryPolicy(a.cfg.MaxRetries, a.cfg.RetryBaseDelay),
		download.WithDownloadRateLimit(a.cfg.DownloadRateLimit),
		download.WithBTTransfer(btprotocol.NewDownloader(settings)),
	)
	if err != nil {
		_ = store.Close()
		return err
	}
	apiServer := httpapi.New(
		time.Now(),
		httpapi.WithTaskService(manager),
		httpapi.WithSettingsService(settings),
	)
	defer apiServer.Close()

	listener, err := net.Listen("tcp", a.cfg.Address)
	if err != nil {
		return err
	}
	server := &http.Server{
		Handler:           apiServer.Handler(),
		ReadHeaderTimeout: 10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	a.logger.Info("downpeed engine started", "address", listener.Addr().String())
	if ready != nil {
		ready(listener.Addr().String())
	}
	errCh := make(chan error, 1)
	go func() {
		errCh <- server.Serve(listener)
	}()

	select {
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := server.Shutdown(shutdownCtx); err != nil {
			return err
		}
		if err := apiServer.Close(); err != nil {
			return err
		}
		a.logger.Info("downpeed engine stopped")
		return nil
	case err := <-errCh:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	}
}

func ensureDefaultDownloadDirectory(directory string) error {
	if err := os.MkdirAll(directory, 0o755); err != nil {
		return fmt.Errorf("create default download directory: %w", err)
	}
	return nil
}
