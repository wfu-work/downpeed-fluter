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
	enginediagnostics "github.com/wfu-work/downpeed-fluter/backend/internal/diagnostics"
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
	databasePath := filepath.Join(a.cfg.DataDir, "tasks.db")
	store, err := repository.OpenBoltTaskStore(databasePath)
	if err != nil {
		return err
	}
	settings, err := download.NewSettingsManager(
		context.Background(),
		store,
		defaultDownloadDirectory,
		download.WithDefaultSchedulerSettings(download.SchedulerSettings{
			MaxConcurrentTasks: a.cfg.MaxConcurrentTasks,
			DownloadRateLimit:  a.cfg.DownloadRateLimit,
			MaxRetries:         a.cfg.MaxRetries,
		}),
	)
	if err != nil {
		_ = store.Close()
		return err
	}
	engineSettings, err := settings.GetSettings(context.Background())
	if err != nil {
		_ = store.Close()
		return err
	}
	proxyRuntime, err := httpprotocol.NewProxyRuntime(engineSettings.Proxy)
	if err != nil {
		_ = store.Close()
		return err
	}
	httpClient := &http.Client{Transport: proxyRuntime}
	manager, err := download.NewPersistentManager(
		context.Background(),
		httpprotocol.NewDownloader(httpClient),
		store,
		download.WithMaxConcurrentTasks(engineSettings.Scheduler.MaxConcurrentTasks),
		download.WithRetryPolicy(engineSettings.Scheduler.MaxRetries, a.cfg.RetryBaseDelay),
		download.WithDownloadRateLimit(engineSettings.Scheduler.DownloadRateLimit),
		download.WithFileConflictPolicy(engineSettings.FileConflictPolicy),
		download.WithBTTransfer(btprotocol.NewDownloader(settings)),
	)
	if err != nil {
		_ = store.Close()
		return err
	}
	settings.SetSchedulerSettingsApplier(manager.ApplySchedulerSettings)
	settings.SetFileConflictPolicyApplier(manager.ApplyFileConflictPolicy)
	settings.SetProxySettingsApplier(proxyRuntime.ApplySettings)
	startedAt := time.Now().UTC()
	apiServer := httpapi.New(
		startedAt,
		httpapi.WithTaskService(manager),
		httpapi.WithSettingsService(settings),
		httpapi.WithProxyService(proxyRuntime),
		httpapi.WithResolver(httpprotocol.NewResolver(httpClient)),
		httpapi.WithDiagnosticsService(enginediagnostics.New(enginediagnostics.Config{
			DataDirectory: a.cfg.DataDir,
			DatabasePath:  databasePath,
			StartedAt:     startedAt,
		}, manager, settings)),
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
