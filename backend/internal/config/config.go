package config

import (
	"errors"
	"flag"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const (
	DefaultAddress            = "127.0.0.1:17680"
	DefaultMaxConcurrentTasks = 3
	DefaultMaxRetries         = 2
	DefaultRetryBaseDelay     = time.Second
)

type Config struct {
	Address                  string
	AllowRemote              bool
	DataDir                  string
	DefaultDownloadDirectory string
	MaxConcurrentTasks       int
	MaxRetries               int
	RetryBaseDelay           time.Duration
	DownloadRateLimit        int64
}

func Parse(args []string, output io.Writer) (Config, error) {
	fs := flag.NewFlagSet("downpeedd", flag.ContinueOnError)
	fs.SetOutput(output)

	userConfigDir, err := os.UserConfigDir()
	if err != nil {
		return Config{}, fmt.Errorf("resolve user configuration directory: %w", err)
	}
	userHomeDir, err := os.UserHomeDir()
	if err != nil {
		return Config{}, fmt.Errorf("resolve user home directory: %w", err)
	}
	cfg := Config{
		DataDir:                  filepath.Join(userConfigDir, "Downpeed"),
		DefaultDownloadDirectory: defaultDownloadDirectory(userHomeDir),
		MaxConcurrentTasks:       DefaultMaxConcurrentTasks,
		MaxRetries:               DefaultMaxRetries,
		RetryBaseDelay:           DefaultRetryBaseDelay,
	}
	fs.StringVar(&cfg.Address, "address", DefaultAddress, "HTTP listen address")
	fs.BoolVar(&cfg.AllowRemote, "allow-remote", false, "allow a non-loopback listen address")
	fs.StringVar(&cfg.DataDir, "data-dir", cfg.DataDir, "directory for the local task database")
	fs.IntVar(&cfg.MaxConcurrentTasks, "max-concurrent-tasks", cfg.MaxConcurrentTasks, "maximum number of active download tasks")
	fs.IntVar(&cfg.MaxRetries, "max-retries", cfg.MaxRetries, "automatic retries after a transient transfer failure")
	fs.DurationVar(&cfg.RetryBaseDelay, "retry-base-delay", cfg.RetryBaseDelay, "base delay for exponential retry backoff")
	fs.Int64Var(&cfg.DownloadRateLimit, "download-rate-limit", 0, "global download limit in bytes per second; 0 disables limiting")
	if err := fs.Parse(args); err != nil {
		return Config{}, err
	}
	if fs.NArg() != 0 {
		return Config{}, fmt.Errorf("unexpected arguments: %s", strings.Join(fs.Args(), " "))
	}
	cfg.DataDir = filepath.Clean(strings.TrimSpace(cfg.DataDir))
	cfg.DefaultDownloadDirectory = filepath.Clean(strings.TrimSpace(cfg.DefaultDownloadDirectory))
	if err := cfg.Validate(); err != nil {
		return Config{}, err
	}
	return cfg, nil
}

func (cfg Config) Validate() error {
	if !filepath.IsAbs(filepath.Clean(strings.TrimSpace(cfg.DataDir))) {
		return errors.New("data directory must be an absolute path")
	}
	if strings.TrimSpace(cfg.DefaultDownloadDirectory) == "" {
		userHomeDir, err := os.UserHomeDir()
		if err != nil {
			return fmt.Errorf("resolve user home directory: %w", err)
		}
		cfg.DefaultDownloadDirectory = defaultDownloadDirectory(userHomeDir)
	}
	if !filepath.IsAbs(filepath.Clean(strings.TrimSpace(cfg.DefaultDownloadDirectory))) {
		return errors.New("default download directory must be an absolute path")
	}
	if cfg.MaxConcurrentTasks <= 0 || cfg.MaxConcurrentTasks > 64 {
		return errors.New("maximum concurrent tasks must be between 1 and 64")
	}
	if cfg.MaxRetries < 0 || cfg.MaxRetries > 10 {
		return errors.New("maximum retries must be between 0 and 10")
	}
	if cfg.MaxRetries > 0 && cfg.RetryBaseDelay <= 0 {
		return errors.New("retry base delay must be positive when retries are enabled")
	}
	if cfg.DownloadRateLimit < 0 {
		return errors.New("download rate limit cannot be negative")
	}
	host, port, err := net.SplitHostPort(cfg.Address)
	if err != nil {
		return fmt.Errorf("invalid address %q: %w", cfg.Address, err)
	}
	if port == "" {
		return errors.New("listen port is required")
	}
	if cfg.AllowRemote {
		return nil
	}
	if host == "localhost" {
		return nil
	}
	ip := net.ParseIP(host)
	if ip == nil || !ip.IsLoopback() {
		return errors.New("non-loopback address requires --allow-remote")
	}
	return nil
}
