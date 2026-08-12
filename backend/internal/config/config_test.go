package config

import (
	"io"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestParseDefaultsToLoopback(t *testing.T) {
	cfg, err := Parse(nil, io.Discard)
	if err != nil {
		t.Fatalf("Parse() error = %v", err)
	}
	if cfg.Address != DefaultAddress {
		t.Fatalf("Address = %q, want %q", cfg.Address, DefaultAddress)
	}
	if !filepath.IsAbs(cfg.DataDir) {
		t.Fatalf("DataDir = %q, want absolute path", cfg.DataDir)
	}
	if !filepath.IsAbs(cfg.DefaultDownloadDirectory) || filepath.Base(cfg.DefaultDownloadDirectory) != "Downloads" {
		t.Fatalf("DefaultDownloadDirectory = %q, want system Downloads folder", cfg.DefaultDownloadDirectory)
	}
	if cfg.MaxConcurrentTasks != DefaultMaxConcurrentTasks || cfg.MaxRetries != DefaultMaxRetries || cfg.RetryBaseDelay != DefaultRetryBaseDelay || cfg.DownloadRateLimit != 0 {
		t.Fatalf("scheduler defaults = %#v", cfg)
	}
}

func TestParseAcceptsSchedulerAndRateLimitSettings(t *testing.T) {
	cfg, err := Parse([]string{
		"--max-concurrent-tasks", "5",
		"--max-retries", "4",
		"--retry-base-delay", "250ms",
		"--download-rate-limit", "1048576",
	}, io.Discard)
	if err != nil {
		t.Fatal(err)
	}
	if cfg.MaxConcurrentTasks != 5 || cfg.MaxRetries != 4 || cfg.RetryBaseDelay != 250*time.Millisecond || cfg.DownloadRateLimit != 1048576 {
		t.Fatalf("scheduler config = %#v", cfg)
	}
}

func TestParseRejectsInvalidSchedulerSettings(t *testing.T) {
	tests := [][]string{
		{"--max-concurrent-tasks", "0"},
		{"--max-concurrent-tasks", "65"},
		{"--max-retries", "-1"},
		{"--max-retries", "11"},
		{"--max-retries", "1", "--retry-base-delay", "0s"},
		{"--download-rate-limit", "-1"},
	}
	for _, args := range tests {
		if _, err := Parse(args, io.Discard); err == nil {
			t.Fatalf("Parse(%v) error = nil", args)
		}
	}
}

func TestParseAcceptsExplicitDataDirectory(t *testing.T) {
	directory := t.TempDir()
	cfg, err := Parse([]string{"--data-dir", directory}, io.Discard)
	if err != nil {
		t.Fatal(err)
	}
	if cfg.DataDir != directory {
		t.Fatalf("DataDir = %q, want %q", cfg.DataDir, directory)
	}
}

func TestParseRejectsRelativeDataDirectory(t *testing.T) {
	if _, err := Parse([]string{"--data-dir", "./data"}, io.Discard); err == nil {
		t.Fatal("Parse() error = nil")
	}
}

func TestParseRejectsRemoteAddressByDefault(t *testing.T) {
	_, err := Parse([]string{"--address", "0.0.0.0:17680"}, io.Discard)
	if err == nil {
		t.Fatal("Parse() error = nil, want remote address rejection")
	}
}

func TestParseAllowsExplicitRemoteAddress(t *testing.T) {
	cfg, err := Parse(
		[]string{"--address", "0.0.0.0:17680", "--allow-remote"},
		io.Discard,
	)
	if err != nil {
		t.Fatalf("Parse() error = %v", err)
	}
	if !cfg.AllowRemote {
		t.Fatal("AllowRemote = false, want true")
	}
}

func TestLinuxDownloadDirectoryUsesXDGUserDirectory(t *testing.T) {
	home := t.TempDir()
	configHome := filepath.Join(home, "config")
	if err := os.MkdirAll(configHome, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(
		filepath.Join(configHome, "user-dirs.dirs"),
		[]byte("XDG_DOWNLOAD_DIR=\"$HOME/下载\"\n"),
		0o600,
	); err != nil {
		t.Fatal(err)
	}
	t.Setenv("XDG_CONFIG_HOME", configHome)
	if got := linuxDownloadDirectory(home); got != filepath.Join(home, "下载") {
		t.Fatalf("linuxDownloadDirectory() = %q", got)
	}
}
