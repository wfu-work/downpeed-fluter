package download

import (
	"context"
	"sync"
	"time"
)

type BandwidthLimiter interface {
	WaitN(context.Context, int) error
}

type bandwidthLimiter struct {
	mu      sync.Mutex
	rate    float64
	burst   float64
	tokens  float64
	last    time.Time
	changed chan struct{}
}

func NewBandwidthLimiter(bytesPerSecond int64) *bandwidthLimiter {
	limiter := &bandwidthLimiter{
		last:    time.Now(),
		changed: make(chan struct{}),
	}
	limiter.setBytesPerSecondLocked(bytesPerSecond)
	return limiter
}

func (limiter *bandwidthLimiter) SetBytesPerSecond(bytesPerSecond int64) {
	limiter.mu.Lock()
	limiter.refillLocked(time.Now())
	limiter.setBytesPerSecondLocked(bytesPerSecond)
	close(limiter.changed)
	limiter.changed = make(chan struct{})
	limiter.mu.Unlock()
}

func (limiter *bandwidthLimiter) WaitN(ctx context.Context, count int) error {
	if count <= 0 {
		return nil
	}
	remaining := float64(count)
	for remaining > 0 {
		for {
			limiter.mu.Lock()
			now := time.Now()
			limiter.refillLocked(now)
			if limiter.rate <= 0 {
				limiter.mu.Unlock()
				return nil
			}
			charge := remaining
			if charge > limiter.burst {
				charge = limiter.burst
			}
			if limiter.tokens >= charge {
				limiter.tokens -= charge
				limiter.mu.Unlock()
				remaining -= charge
				break
			}
			wait := time.Duration((charge - limiter.tokens) / limiter.rate * float64(time.Second))
			changed := limiter.changed
			limiter.mu.Unlock()
			if wait < time.Millisecond {
				wait = time.Millisecond
			}
			timer := time.NewTimer(wait)
			select {
			case <-ctx.Done():
				if !timer.Stop() {
					select {
					case <-timer.C:
					default:
					}
				}
				return ctx.Err()
			case <-changed:
				if !timer.Stop() {
					select {
					case <-timer.C:
					default:
					}
				}
			case <-timer.C:
			}
		}
	}
	return nil
}

func (limiter *bandwidthLimiter) refillLocked(now time.Time) {
	if limiter.rate > 0 {
		elapsed := now.Sub(limiter.last).Seconds()
		if elapsed > 0 {
			limiter.tokens += elapsed * limiter.rate
			if limiter.tokens > limiter.burst {
				limiter.tokens = limiter.burst
			}
		}
	}
	limiter.last = now
}

func (limiter *bandwidthLimiter) setBytesPerSecondLocked(bytesPerSecond int64) {
	if bytesPerSecond <= 0 {
		limiter.rate = 0
		limiter.burst = 0
		limiter.tokens = 0
		return
	}
	limiter.rate = float64(bytesPerSecond)
	limiter.burst = limiter.rate
	if limiter.burst < 64*1024 {
		limiter.burst = 64 * 1024
	}
	if limiter.tokens > limiter.burst {
		limiter.tokens = limiter.burst
	}
}
