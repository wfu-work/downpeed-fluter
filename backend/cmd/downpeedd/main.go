package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"github.com/wfu-work/downpeed-fluter/backend/internal/app"
	"github.com/wfu-work/downpeed-fluter/backend/internal/config"
)

func main() {
	logger := slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))
	cfg, err := config.Parse(os.Args[1:], os.Stderr)
	if err != nil {
		logger.Error("invalid configuration", "error", err)
		os.Exit(2)
	}

	ctx, stop := signal.NotifyContext(
		context.Background(),
		os.Interrupt,
		syscall.SIGTERM,
	)
	defer stop()

	if err := app.New(cfg, logger).Run(ctx); err != nil {
		logger.Error("downpeed engine failed", "error", err)
		os.Exit(1)
	}
}
