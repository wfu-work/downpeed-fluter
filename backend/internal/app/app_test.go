package app

import (
	"context"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"testing"

	"github.com/wfu-work/downpeed-fluter/backend/internal/config"
)

func TestRunCreatesTaskDatabaseAndStopsCleanly(t *testing.T) {
	directory := t.TempDir()
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	err := New(config.Config{
		Address:            "127.0.0.1:0",
		DataDir:            directory,
		MaxConcurrentTasks: config.DefaultMaxConcurrentTasks,
		MaxRetries:         config.DefaultMaxRetries,
		RetryBaseDelay:     config.DefaultRetryBaseDelay,
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
}
