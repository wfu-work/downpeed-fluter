package download

import (
	"context"
	"errors"
	"testing"
	"time"
)

func TestBandwidthLimiterPacesBytesAndHonorsCancellation(t *testing.T) {
	limiter := NewBandwidthLimiter(10_000)
	startedAt := time.Now()
	if err := limiter.WaitN(context.Background(), 1_000); err != nil {
		t.Fatal(err)
	}
	elapsed := time.Since(startedAt)
	if elapsed < 70*time.Millisecond || elapsed > time.Second {
		t.Fatalf("limited wait = %s, want approximately 100ms", elapsed)
	}

	slowLimiter := NewBandwidthLimiter(1)
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Millisecond)
	defer cancel()
	startedAt = time.Now()
	err := slowLimiter.WaitN(ctx, 1_000)
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("canceled wait error = %v", err)
	}
	if time.Since(startedAt) > 250*time.Millisecond {
		t.Fatal("limiter did not stop promptly after context cancellation")
	}
}
