package app

import (
	"context"
	"io"
	"log/slog"
	"net/http"
	"os"
	"path/filepath"
	"testing"

	"github.com/wfu-work/downpeed-fluter/backend/internal/config"
)

func TestRunCreatesTaskDatabaseAndStopsCleanly(t *testing.T) {
	directory := t.TempDir()
	downloadDirectory := filepath.Join(directory, "Downloads")
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	err := New(config.Config{
		Address:                  "127.0.0.1:0",
		DataDir:                  directory,
		DefaultDownloadDirectory: downloadDirectory,
		MaxConcurrentTasks:       config.DefaultMaxConcurrentTasks,
		MaxRetries:               config.DefaultMaxRetries,
		RetryBaseDelay:           config.DefaultRetryBaseDelay,
	}, logger).Run(ctx)
	if err != nil {
		t.Fatal(err)
	}
	info, err := os.Stat(filepath.Join(directory, "tasks.db"))
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm()&0o077 != 0 {
		t.Fatalf("database permissions = %o", info.Mode().Perm())
	}
	if info, err = os.Stat(downloadDirectory); err != nil || !info.IsDir() {
		t.Fatalf("default download directory = %#v, error = %v", info, err)
	}
}

func TestRunWithReadyPublishesUsableListener(t *testing.T) {
	directory := t.TempDir()
	ctx, cancel := context.WithCancel(context.Background())
	ready := make(chan string, 1)
	done := make(chan error, 1)
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	go func() {
		done <- New(config.Config{
			Address:                  "127.0.0.1:0",
			DataDir:                  directory,
			DefaultDownloadDirectory: filepath.Join(directory, "Downloads"),
			MaxConcurrentTasks:       config.DefaultMaxConcurrentTasks,
			MaxRetries:               config.DefaultMaxRetries,
			RetryBaseDelay:           config.DefaultRetryBaseDelay,
		}, logger).RunWithReady(ctx, func(address string) {
			ready <- address
		})
	}()

	address := <-ready
	response, err := http.Get("http://" + address + "/api/v1/health")
	if err != nil {
		t.Fatal(err)
	}
	_ = response.Body.Close()
	if response.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want %d", response.StatusCode, http.StatusOK)
	}
	cancel()
	if err = <-done; err != nil {
		t.Fatal(err)
	}
}
