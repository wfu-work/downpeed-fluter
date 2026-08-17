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

func TestBandwidthLimiterAppliesRuntimeRateChanges(t *testing.T) {
	limiter := NewBandwidthLimiter(1)
	done := make(chan error, 1)
	go func() {
		done <- limiter.WaitN(context.Background(), 1_000)
	}()
	time.Sleep(20 * time.Millisecond)
	limiter.SetBytesPerSecond(0)
	select {
	case err := <-done:
		if err != nil {
			t.Fatal(err)
		}
	case <-time.After(250 * time.Millisecond):
		t.Fatal("unlimited rate did not release a pending wait")
	}

	limiter.SetBytesPerSecond(20_000)
	startedAt := time.Now()
	if err := limiter.WaitN(context.Background(), 1_000); err != nil {
		t.Fatal(err)
	}
	if elapsed := time.Since(startedAt); elapsed < 30*time.Millisecond || elapsed > 500*time.Millisecond {
		t.Fatalf("updated limited wait = %s, want approximately 50ms", elapsed)
	}
}
