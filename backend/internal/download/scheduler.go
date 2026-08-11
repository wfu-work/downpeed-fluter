package download

import (
	"context"
	"errors"
	"io"
	"net"
	"os"
	"time"
)

const (
	DefaultMaxConcurrentTasks = 3
	DefaultMaxRetries         = 2
	DefaultRetryBaseDelay     = time.Second
	defaultRetryMaxDelay      = 30 * time.Second
)

type managerConfig struct {
	maxConcurrentTasks int
	maxRetries         int
	retryBaseDelay     time.Duration
	downloadRateLimit  int64
}

type ManagerOption func(*managerConfig)

func WithMaxConcurrentTasks(value int) ManagerOption {
	return func(config *managerConfig) {
		if value > 0 {
			config.maxConcurrentTasks = value
		}
	}
}

func WithRetryPolicy(maxRetries int, baseDelay time.Duration) ManagerOption {
	return func(config *managerConfig) {
		if maxRetries >= 0 {
			config.maxRetries = maxRetries
		}
		if baseDelay > 0 {
			config.retryBaseDelay = baseDelay
		}
	}
}

func WithDownloadRateLimit(bytesPerSecond int64) ManagerOption {
	return func(config *managerConfig) {
		if bytesPerSecond >= 0 {
			config.downloadRateLimit = bytesPerSecond
		}
	}
}

func defaultManagerConfig() managerConfig {
	return managerConfig{
		maxConcurrentTasks: DefaultMaxConcurrentTasks,
		maxRetries:         DefaultMaxRetries,
		retryBaseDelay:     DefaultRetryBaseDelay,
	}
}

func resolveManagerConfig(options []ManagerOption) managerConfig {
	config := defaultManagerConfig()
	for _, option := range options {
		if option != nil {
			option(&config)
		}
	}
	return config
}

func (m *Manager) enqueueLocked(id string) {
	m.removeFromQueueLocked(id)
	m.queue = append(m.queue, id)
}

func (m *Manager) removeFromQueueLocked(id string) {
	for index := 0; index < len(m.queue); index++ {
		if m.queue[index] != id {
			continue
		}
		m.queue = append(m.queue[:index], m.queue[index+1:]...)
		index--
	}
}

func (m *Manager) fillAvailableSlotsLocked() []Task {
	if m.closed {
		return nil
	}
	updates := make([]Task, 0)
	for len(m.runs) < m.maxConcurrentTasks && len(m.queue) > 0 {
		id := m.queue[0]
		m.queue = m.queue[1:]
		task, exists := m.tasks[id]
		if !exists || task.State != TaskStateQueued {
			continue
		}
		request, exists := m.requests[id]
		if !exists {
			continue
		}
		now := time.Now().UTC()
		task.State = TaskStateDownloading
		task.SpeedBPS = 0
		task.Error = nil
		task.NextRetryAt = nil
		task.CompletedAt = nil
		task.UpdatedAt = now
		request.Limiter = m.limiter
		m.tasks[id] = task
		m.requests[id] = request
		_ = m.persistTaskLocked(task)
		m.startRunLocked(id, request)
		updates = append(updates, cloneTask(task))
	}
	return updates
}

func (m *Manager) scheduleRetryLocked(id string, task Task, transferErr error) (Task, bool) {
	taskError := taskErrorFor(transferErr)
	if !isRetryableTransferError(transferErr) || task.RetryCount >= m.maxRetries {
		return task, false
	}

	request := m.requests[id]
	if request.Checkpoint != nil {
		_ = os.Remove(request.WorkPath)
		request.Checkpoint = nil
		request.Offset = 0
		task.Downloaded = 0
	} else {
		size, err := partialFileSize(request.WorkPath)
		if err != nil {
			_ = os.Remove(request.WorkPath)
			size = 0
		}
		if size > 0 && request.Validator.IfRangeValue() == "" {
			_ = os.Remove(request.WorkPath)
			size = 0
		}
		request.Offset = size
		task.Downloaded = size
	}
	request.Limiter = m.limiter
	m.requests[id] = request

	delay := m.retryBaseDelay
	for retry := 0; retry < task.RetryCount && delay < defaultRetryMaxDelay; retry++ {
		delay *= 2
		if delay > defaultRetryMaxDelay {
			delay = defaultRetryMaxDelay
		}
	}
	nextRetryAt := time.Now().UTC().Add(delay)
	task.State = TaskStateRetrying
	task.SpeedBPS = 0
	task.RetryCount++
	task.NextRetryAt = &nextRetryAt
	task.CompletedAt = nil
	task.Error = taskError
	task.UpdatedAt = time.Now().UTC()
	m.tasks[id] = task
	_ = m.persistTaskLocked(task)

	m.retryWG.Add(1)
	go m.waitForRetry(id, nextRetryAt)
	return task, true
}

func isRetryableTransferError(err error) bool {
	if errors.Is(err, ErrRemoteTemporary) || errors.Is(err, io.ErrUnexpectedEOF) || errors.Is(err, context.DeadlineExceeded) {
		return true
	}
	var networkError net.Error
	return errors.As(err, &networkError) && (networkError.Timeout() || networkError.Temporary())
}

func (m *Manager) waitForRetry(id string, retryAt time.Time) {
	defer m.retryWG.Done()
	timer := time.NewTimer(time.Until(retryAt))
	defer timer.Stop()
	select {
	case <-timer.C:
	case <-m.rootCtx.Done():
		return
	}

	m.mu.Lock()
	if m.closed {
		m.mu.Unlock()
		return
	}
	task, exists := m.tasks[id]
	if !exists || task.State != TaskStateRetrying || task.NextRetryAt == nil || !task.NextRetryAt.Equal(retryAt) {
		m.mu.Unlock()
		return
	}
	task.State = TaskStateQueued
	task.NextRetryAt = nil
	task.UpdatedAt = time.Now().UTC()
	m.tasks[id] = task
	_ = m.persistTaskLocked(task)
	m.enqueueLocked(id)
	updates := m.fillAvailableSlotsLocked()
	if !containsTask(updates, id) {
		updates = append(updates, cloneTask(task))
	}
	m.mu.Unlock()
	for _, update := range updates {
		m.publish(update)
	}
}

func containsTask(tasks []Task, id string) bool {
	for _, task := range tasks {
		if task.ID == id {
			return true
		}
	}
	return false
}
