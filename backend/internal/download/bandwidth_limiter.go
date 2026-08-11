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
	mu     sync.Mutex
	rate   float64
	burst  float64
	tokens float64
	last   time.Time
}

func NewBandwidthLimiter(bytesPerSecond int64) BandwidthLimiter {
	if bytesPerSecond <= 0 {
		return nil
	}
	burst := float64(bytesPerSecond)
	if burst < 64*1024 {
		burst = 64 * 1024
	}
	return &bandwidthLimiter{
		rate:  float64(bytesPerSecond),
		burst: burst,
		last:  time.Now(),
	}
}

func (limiter *bandwidthLimiter) WaitN(ctx context.Context, count int) error {
	if count <= 0 {
		return nil
	}
	remaining := float64(count)
	for remaining > 0 {
		charge := remaining
		if charge > limiter.burst {
			charge = limiter.burst
		}
		for {
			limiter.mu.Lock()
			now := time.Now()
			elapsed := now.Sub(limiter.last).Seconds()
			if elapsed > 0 {
				limiter.tokens += elapsed * limiter.rate
				if limiter.tokens > limiter.burst {
					limiter.tokens = limiter.burst
				}
				limiter.last = now
			}
			if limiter.tokens >= charge {
				limiter.tokens -= charge
				limiter.mu.Unlock()
				break
			}
			wait := time.Duration((charge - limiter.tokens) / limiter.rate * float64(time.Second))
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
			case <-timer.C:
			}
		}
		remaining -= charge
	}
	return nil
}
