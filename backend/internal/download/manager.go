package download

import (
	"context"
	"errors"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

type Manager struct {
	transfer           Transfer
	rootCtx            context.Context
	stop               context.CancelCauseFunc
	sequence           atomic.Uint64
	operationMu        sync.Mutex
	store              TaskStore
	closed             bool
	closeOnce          sync.Once
	closeErr           error
	maxConcurrentTasks int
	maxRetries         int
	retryBaseDelay     time.Duration
	limiter            BandwidthLimiter
	retryWG            sync.WaitGroup

	mu       sync.RWMutex
	tasks    map[string]Task
	requests map[string]TransferRequest
	runs     map[string]*taskRun
	queue    []string

	subscriberMu sync.RWMutex
	subscribers  map[uint64]chan TaskEvent
	subscriberID atomic.Uint64
}

type taskRun struct {
	cancel context.CancelCauseFunc
	done   chan struct{}
}

func NewManager(parent context.Context, transfer Transfer, options ...ManagerOption) *Manager {
	manager, _ := newManager(parent, transfer, nil, options...)
	return manager
}

func NewPersistentManager(parent context.Context, transfer Transfer, store TaskStore, options ...ManagerOption) (*Manager, error) {
	if store == nil {
		return nil, fmt.Errorf("%w: task store is required", ErrTaskPersistence)
	}
	return newManager(parent, transfer, store, options...)
}

func newManager(parent context.Context, transfer Transfer, store TaskStore, options ...ManagerOption) (*Manager, error) {
	if parent == nil {
		parent = context.Background()
	}
	managerConfig := resolveManagerConfig(options)
	rootCtx, stop := context.WithCancelCause(parent)
	manager := &Manager{
		transfer:           transfer,
		rootCtx:            rootCtx,
		stop:               stop,
		store:              store,
		maxConcurrentTasks: managerConfig.maxConcurrentTasks,
		maxRetries:         managerConfig.maxRetries,
		retryBaseDelay:     managerConfig.retryBaseDelay,
		limiter:            NewBandwidthLimiter(managerConfig.downloadRateLimit),
		tasks:              make(map[string]Task),
		requests:           make(map[string]TransferRequest),
		runs:               make(map[string]*taskRun),
		subscribers:        make(map[uint64]chan TaskEvent),
	}
	if store != nil {
		if err := manager.restore(context.Background()); err != nil {
			stop(ErrTransferShutdown)
			return nil, err
		}
		for id, request := range manager.requests {
			request.Limiter = manager.limiter
			manager.requests[id] = request
		}
	}
	return manager, nil
}

func (m *Manager) Create(_ context.Context, input CreateTaskRequest) (Task, error) {
	if m.transfer == nil {
		return Task{}, errors.New("download transfer is not configured")
	}
	m.operationMu.Lock()
	defer m.operationMu.Unlock()
	if m.closed {
		return Task{}, ErrTaskInvalidState
	}
	parsedURL, err := url.ParseRequestURI(strings.TrimSpace(input.URL))
	if err != nil || parsedURL.Host == "" {
		return Task{}, fmt.Errorf("%w: URL must be absolute", ErrInvalidRequest)
	}
	if parsedURL.Scheme != "http" && parsedURL.Scheme != "https" {
		return Task{}, fmt.Errorf("%w: %s", ErrUnsupportedScheme, parsedURL.Scheme)
	}
	if input.ExpectedSize < -1 {
		return Task{}, fmt.Errorf("%w: expected size cannot be less than -1", ErrInvalidRequest)
	}
	validator, err := NormalizeResourceValidator(input.ETag, input.LastModified)
	if err != nil {
		return Task{}, err
	}

	fileName := SafeFileName(input.FileName)
	if fileName == "" {
		return Task{}, fmt.Errorf("%w: file name is required", ErrInvalidDestination)
	}
	directory := filepath.Clean(strings.TrimSpace(input.SaveDirectory))
	if !filepath.IsAbs(directory) {
		return Task{}, fmt.Errorf("%w: save directory must be absolute", ErrInvalidDestination)
	}
	info, err := os.Stat(directory)
	if err != nil || !info.IsDir() {
		return Task{}, fmt.Errorf("%w: save directory is unavailable", ErrInvalidDestination)
	}
	destination := filepath.Join(directory, fileName)
	if _, err = os.Lstat(destination); err == nil {
		return Task{}, ErrDestinationExists
	} else if !errors.Is(err, os.ErrNotExist) {
		return Task{}, fmt.Errorf("%w: destination cannot be checked", ErrInvalidDestination)
	}
	workPath := temporaryPath(destination)
	if _, err = os.Lstat(workPath); err == nil {
		return Task{}, ErrDestinationExists
	} else if !errors.Is(err, os.ErrNotExist) {
		return Task{}, fmt.Errorf("%w: temporary destination cannot be checked", ErrInvalidDestination)
	}

	now := time.Now().UTC()
	id := fmt.Sprintf("%x-%x", now.UnixMilli(), m.sequence.Add(1))
	task := Task{
		ID:            id,
		URL:           parsedURL.String(),
		FinalURL:      parsedURL.String(),
		FileName:      fileName,
		SaveDirectory: directory,
		FilePath:      destination,
		State:         TaskStateQueued,
		Total:         input.ExpectedSize,
		CreatedAt:     now,
		UpdatedAt:     now,
	}
	if task.Total <= 0 {
		task.Total = -1
	}

	m.mu.Lock()
	for {
		if _, exists := m.tasks[task.ID]; !exists {
			break
		}
		now = time.Now().UTC()
		task.ID = fmt.Sprintf("%x-%x", now.UnixMilli(), m.sequence.Add(1))
		task.CreatedAt = now
		task.UpdatedAt = now
	}
	for _, existing := range m.tasks {
		if existing.FilePath == destination &&
			(existing.State == TaskStateQueued ||
				existing.State == TaskStateDownloading ||
				existing.State == TaskStateRetrying ||
				existing.State == TaskStatePaused) {
			m.mu.Unlock()
			return Task{}, ErrDestinationExists
		}
	}
	request := TransferRequest{
		URL:           task.URL,
		Headers:       cloneHeaders(input.Headers),
		Destination:   destination,
		WorkPath:      workPath,
		ExpectedSize:  task.Total,
		AcceptRanges:  input.AcceptRanges,
		AllowSegments: input.AcceptRanges && validator.IfRangeValue() != "" && task.Total >= DefaultSegmentedTransferMinSize,
		Validator:     validator,
		Limiter:       m.limiter,
	}
	m.tasks[task.ID] = task
	m.requests[task.ID] = request
	if err = m.persistTaskLocked(task); err != nil {
		delete(m.tasks, task.ID)
		delete(m.requests, task.ID)
		m.mu.Unlock()
		return Task{}, err
	}
	m.enqueueLocked(task.ID)
	updates := m.fillAvailableSlotsLocked()
	task = m.tasks[task.ID]
	if !containsTask(updates, task.ID) {
		updates = append(updates, cloneTask(task))
	}
	m.mu.Unlock()
	for _, update := range updates {
		m.publish(update)
	}
	return cloneTask(task), nil
}

func (m *Manager) List(context.Context) ([]Task, error) {
	m.mu.RLock()
	tasks := make([]Task, 0, len(m.tasks))
	for _, task := range m.tasks {
		tasks = append(tasks, cloneTask(task))
	}
	m.mu.RUnlock()
	sort.Slice(tasks, func(left, right int) bool {
		return tasks[left].CreatedAt.After(tasks[right].CreatedAt)
	})
	return tasks, nil
}

func (m *Manager) Get(_ context.Context, id string) (Task, error) {
	m.mu.RLock()
	task, ok := m.tasks[id]
	m.mu.RUnlock()
	if !ok {
		return Task{}, ErrTaskNotFound
	}
	return cloneTask(task), nil
}

func (m *Manager) Pause(_ context.Context, id string) (Task, error) {
	m.operationMu.Lock()
	defer m.operationMu.Unlock()
	if m.closed {
		return Task{}, ErrTaskInvalidState
	}

	m.mu.Lock()
	task, ok := m.tasks[id]
	if !ok {
		m.mu.Unlock()
		return Task{}, ErrTaskNotFound
	}
	if task.State != TaskStateDownloading && task.State != TaskStateQueued && task.State != TaskStateRetrying {
		m.mu.Unlock()
		return Task{}, ErrTaskInvalidState
	}
	run := m.runs[id]
	if task.State == TaskStateDownloading && run == nil {
		m.mu.Unlock()
		return Task{}, ErrTaskInvalidState
	}
	m.removeFromQueueLocked(id)
	task.State = TaskStatePaused
	task.SpeedBPS = 0
	task.NextRetryAt = nil
	task.UpdatedAt = time.Now().UTC()
	task.CompletedAt = nil
	m.tasks[id] = task
	_ = m.persistTaskLocked(task)
	m.mu.Unlock()
	if run == nil {
		m.publish(task)
		return cloneTask(task), nil
	}

	run.cancel(ErrTransferPaused)
	<-run.done

	request := m.requests[id]
	downloaded, err := reconciledPartialProgress(task, request)
	if err != nil {
		return Task{}, err
	}
	m.mu.Lock()
	task = m.tasks[id]
	if task.State == TaskStatePaused {
		task.Downloaded = downloaded
		task.UpdatedAt = time.Now().UTC()
		m.tasks[id] = task
		if err = m.persistTaskLocked(task); err != nil {
			m.mu.Unlock()
			return Task{}, err
		}
	}
	m.mu.Unlock()
	m.publish(task)
	return cloneTask(task), nil
}

func (m *Manager) Resume(_ context.Context, id string) (Task, error) {
	m.operationMu.Lock()
	defer m.operationMu.Unlock()
	if m.closed {
		return Task{}, ErrTaskInvalidState
	}

	m.mu.Lock()
	task, ok := m.tasks[id]
	if !ok {
		m.mu.Unlock()
		return Task{}, ErrTaskNotFound
	}
	if task.State != TaskStatePaused {
		m.mu.Unlock()
		return Task{}, ErrTaskInvalidState
	}
	request, ok := m.requests[id]
	if !ok {
		m.mu.Unlock()
		return Task{}, ErrTaskInvalidState
	}
	m.mu.Unlock()

	if _, err := os.Lstat(task.FilePath); err == nil {
		return Task{}, ErrDestinationExists
	} else if !errors.Is(err, os.ErrNotExist) {
		return Task{}, fmt.Errorf("%w: destination cannot be checked", ErrInvalidDestination)
	}
	downloaded, err := reconciledPartialProgress(task, request)
	if err != nil {
		return Task{}, err
	}
	if downloaded != task.Downloaded {
		return Task{}, ErrPartialFileChanged
	}
	if downloaded > 0 && request.Validator.IfRangeValue() == "" {
		return Task{}, ErrResumeNotSupported
	}
	if request.Checkpoint == nil && downloaded == 0 {
		if err = os.Remove(request.WorkPath); err != nil && !errors.Is(err, os.ErrNotExist) {
			return Task{}, fmt.Errorf("%w: empty partial file cannot be replaced", ErrInvalidDestination)
		}
	}
	request.Offset = downloaded
	request.ExpectedSize = task.Total

	m.mu.Lock()
	task = m.tasks[id]
	if task.State != TaskStatePaused {
		m.mu.Unlock()
		return Task{}, ErrTaskInvalidState
	}
	task.State = TaskStateQueued
	task.SpeedBPS = 0
	task.Error = nil
	task.RetryCount = 0
	task.NextRetryAt = nil
	task.CompletedAt = nil
	task.UpdatedAt = time.Now().UTC()
	m.tasks[id] = task
	m.requests[id] = request
	if err = m.persistTaskLocked(task); err != nil {
		task.State = TaskStatePaused
		m.tasks[id] = task
		m.mu.Unlock()
		return Task{}, err
	}
	m.enqueueLocked(id)
	updates := m.fillAvailableSlotsLocked()
	task = m.tasks[id]
	if !containsTask(updates, id) {
		updates = append(updates, cloneTask(task))
	}
	m.mu.Unlock()
	for _, update := range updates {
		m.publish(update)
	}
	return cloneTask(task), nil
}

func (m *Manager) Cancel(_ context.Context, id string) (Task, error) {
	m.operationMu.Lock()
	defer m.operationMu.Unlock()
	if m.closed {
		return Task{}, ErrTaskInvalidState
	}

	m.mu.Lock()
	task, ok := m.tasks[id]
	if !ok {
		m.mu.Unlock()
		return Task{}, ErrTaskNotFound
	}
	if task.State != TaskStateDownloading && task.State != TaskStateQueued && task.State != TaskStateRetrying && task.State != TaskStatePaused {
		m.mu.Unlock()
		return Task{}, ErrTaskInvalidState
	}
	run := m.runs[id]
	request := m.requests[id]
	m.removeFromQueueLocked(id)
	request.Checkpoint = nil
	m.requests[id] = request
	now := time.Now().UTC()
	task.State = TaskStateCanceled
	task.SpeedBPS = 0
	task.NextRetryAt = nil
	task.UpdatedAt = now
	task.CompletedAt = &now
	m.tasks[id] = task
	persistErr := m.persistTaskLocked(task)
	m.mu.Unlock()
	if run != nil {
		run.cancel(ErrTransferCanceled)
		<-run.done
	}
	_ = os.Remove(request.WorkPath)
	if persistErr != nil {
		return Task{}, persistErr
	}
	m.publish(task)
	return cloneTask(task), nil
}

func (m *Manager) Subscribe(ctx context.Context) <-chan TaskEvent {
	channel := make(chan TaskEvent, 32)
	id := m.subscriberID.Add(1)
	m.subscriberMu.Lock()
	m.subscribers[id] = channel
	m.subscriberMu.Unlock()
	go func() {
		select {
		case <-ctx.Done():
		case <-m.rootCtx.Done():
		}
		m.subscriberMu.Lock()
		if current, ok := m.subscribers[id]; ok {
			delete(m.subscribers, id)
			close(current)
		}
		m.subscriberMu.Unlock()
	}()
	return channel
}

func (m *Manager) Close() error {
	m.closeOnce.Do(func() {
		m.operationMu.Lock()

		m.mu.Lock()
		m.closed = true
		runs := make([]*taskRun, 0, len(m.runs))
		for id, task := range m.tasks {
			if run := m.runs[id]; run != nil {
				runs = append(runs, run)
			}
			if task.State == TaskStateDownloading || task.State == TaskStateQueued || task.State == TaskStateRetrying {
				task.State = TaskStatePaused
				task.SpeedBPS = 0
				task.NextRetryAt = nil
				task.CompletedAt = nil
				task.UpdatedAt = time.Now().UTC()
				m.tasks[id] = task
				_ = m.persistTaskLocked(task)
			}
		}
		m.queue = nil
		m.mu.Unlock()

		m.stop(ErrTransferShutdown)
		for _, run := range runs {
			<-run.done
		}
		m.retryWG.Wait()

		m.mu.Lock()
		for id, task := range m.tasks {
			if task.State != TaskStatePaused {
				continue
			}
			request := m.requests[id]
			downloaded, err := reconciledPartialProgress(task, request)
			if err == nil {
				task.Downloaded = downloaded
				task.UpdatedAt = time.Now().UTC()
				m.tasks[id] = task
			}
			if err = m.persistTaskLocked(task); err != nil && m.closeErr == nil {
				m.closeErr = err
			}
		}
		m.mu.Unlock()
		m.operationMu.Unlock()

		if m.store != nil {
			if err := m.store.Close(); err != nil && m.closeErr == nil {
				m.closeErr = err
			}
		}
	})
	return m.closeErr
}

func (m *Manager) startRunLocked(id string, request TransferRequest) {
	transferCtx, cancel := context.WithCancelCause(m.rootCtx)
	run := &taskRun{cancel: cancel, done: make(chan struct{})}
	m.runs[id] = run
	go m.run(transferCtx, id, request, run)
}

func (m *Manager) run(ctx context.Context, id string, request TransferRequest, run *taskRun) {
	defer close(run.done)
	result, err := m.transfer.Download(ctx, request, func(progress TransferProgress) {
		m.mu.Lock()
		task, ok := m.tasks[id]
		currentRun := m.runs[id]
		acceptPausedCheckpoint := task.State == TaskStatePaused && progress.Checkpoint != nil && currentRun == run
		if !ok || (task.State != TaskStateDownloading && !acceptPausedCheckpoint) {
			m.mu.Unlock()
			return
		}
		if progress.Checkpoint != nil {
			downloaded, checkpointErr := ValidateTransferCheckpoint(progress.Checkpoint, progress.Total)
			if checkpointErr != nil || downloaded != progress.Downloaded {
				m.mu.Unlock()
				return
			}
			request := m.requests[id]
			request.Checkpoint = CloneTransferCheckpoint(progress.Checkpoint)
			request.ExpectedSize = progress.Total
			request.AcceptRanges = true
			request.AllowSegments = true
			m.requests[id] = request
		}
		task.Downloaded = progress.Downloaded
		task.Total = progress.Total
		if task.State == TaskStatePaused {
			task.SpeedBPS = 0
		} else {
			task.SpeedBPS = progress.SpeedBPS
		}
		task.UpdatedAt = time.Now().UTC()
		m.tasks[id] = task
		_ = m.persistTaskLocked(task)
		m.mu.Unlock()
		m.publish(task)
	})

	m.mu.Lock()
	task, ok := m.tasks[id]
	if !ok || task.State != TaskStateDownloading {
		if m.runs[id] == run {
			delete(m.runs, id)
		}
		updates := m.fillAvailableSlotsLocked()
		m.mu.Unlock()
		for _, update := range updates {
			m.publish(update)
		}
		return
	}
	now := time.Now().UTC()
	task.UpdatedAt = now
	task.SpeedBPS = 0
	if m.runs[id] == run {
		delete(m.runs, id)
	}
	storedRequest := m.requests[id]
	retryScheduled := false
	if err == nil {
		task.State = TaskStateCompleted
		task.FinalURL = result.FinalURL
		task.Downloaded = result.Size
		task.Total = result.Size
		task.Error = nil
		task.NextRetryAt = nil
		task.CompletedAt = &now
	} else if errors.Is(err, context.Canceled) {
		task.State = TaskStateCanceled
		task.NextRetryAt = nil
		task.CompletedAt = &now
	} else {
		if retriedTask, scheduled := m.scheduleRetryLocked(id, task, err); scheduled {
			task = retriedTask
			retryScheduled = true
		} else {
			task.State = TaskStateFailed
			task.Error = taskErrorFor(err)
			task.NextRetryAt = nil
			task.CompletedAt = &now
		}
	}
	if !retryScheduled {
		storedRequest.Checkpoint = nil
		m.requests[id] = storedRequest
		m.tasks[id] = task
		_ = m.persistTaskLocked(task)
	}
	updates := m.fillAvailableSlotsLocked()
	m.mu.Unlock()
	m.publish(task)
	for _, update := range updates {
		m.publish(update)
	}
}

func (m *Manager) publish(task Task) {
	event := TaskEvent{Type: TaskUpdatedEvent, Task: cloneTask(task)}
	m.subscriberMu.RLock()
	defer m.subscriberMu.RUnlock()
	for _, subscriber := range m.subscribers {
		select {
		case subscriber <- event:
		default:
		}
	}
}

func taskErrorFor(err error) *TaskError {
	switch {
	case errors.Is(err, ErrDestinationExists):
		return &TaskError{Code: "destination_exists", Message: "A file already exists at the selected destination.", Retryable: false}
	case errors.Is(err, ErrInvalidDestination):
		return &TaskError{Code: "invalid_destination", Message: "The selected download destination is unavailable.", Retryable: false}
	case errors.Is(err, ErrRemoteRejected):
		return &TaskError{Code: "remote_rejected", Message: "The remote server rejected the download request.", Retryable: false}
	case errors.Is(err, ErrRemoteTemporary):
		return &TaskError{Code: "remote_unavailable", Message: "The remote server is temporarily unavailable.", Retryable: true}
	case errors.Is(err, ErrRemoteChanged):
		return &TaskError{Code: "remote_resource_changed", Message: "The remote file changed after this download was created.", Retryable: false}
	case errors.Is(err, ErrResumeNotSupported):
		return &TaskError{Code: "resume_not_supported", Message: "The remote server cannot safely resume this download.", Retryable: false}
	case errors.Is(err, ErrPartialFileChanged):
		return &TaskError{Code: "partial_file_changed", Message: "The partial download file changed outside Downpeed.", Retryable: false}
	case errors.Is(err, ErrFileConsistency):
		return &TaskError{Code: "file_consistency_failed", Message: "The remote response did not match the expected file layout.", Retryable: false}
	case errors.Is(err, ErrAtomicPublish):
		return &TaskError{Code: "atomic_publish_failed", Message: "The completed file cannot be published atomically at this destination.", Retryable: false}
	default:
		return &TaskError{Code: "download_failed", Message: "The download stopped before the file was complete.", Retryable: isRetryableTransferError(err)}
	}
}

func temporaryPath(destination string) string {
	return filepath.Join(filepath.Dir(destination), "."+filepath.Base(destination)+".downpeed")
}

func partialFileSize(path string) (int64, error) {
	info, err := os.Lstat(path)
	if errors.Is(err, os.ErrNotExist) {
		return 0, nil
	}
	if err != nil {
		return 0, fmt.Errorf("%w: partial file is unavailable", ErrInvalidDestination)
	}
	if !info.Mode().IsRegular() {
		return 0, ErrPartialFileChanged
	}
	return info.Size(), nil
}

func reconciledPartialProgress(task Task, request TransferRequest) (int64, error) {
	if request.Checkpoint == nil {
		if request.AllowSegments {
			_, err := os.Lstat(request.WorkPath)
			if errors.Is(err, os.ErrNotExist) {
				return 0, nil
			}
			return 0, ErrPartialFileChanged
		}
		size, err := partialFileSize(request.WorkPath)
		if err != nil {
			return 0, err
		}
		if task.Total > 0 && size > task.Total {
			return 0, ErrPartialFileChanged
		}
		return size, nil
	}

	downloaded, err := ValidateTransferCheckpoint(request.Checkpoint, task.Total)
	if err != nil {
		return 0, err
	}
	info, err := os.Lstat(request.WorkPath)
	if err != nil || !info.Mode().IsRegular() || info.Size() != request.Checkpoint.Total {
		return 0, ErrPartialFileChanged
	}
	return downloaded, nil
}

func cloneHeaders(headers map[string]string) map[string]string {
	if len(headers) == 0 {
		return nil
	}
	result := make(map[string]string, len(headers))
	for name, value := range headers {
		result[name] = value
	}
	return result
}

func cloneTask(task Task) Task {
	if task.Error != nil {
		errorCopy := *task.Error
		task.Error = &errorCopy
	}
	if task.CompletedAt != nil {
		completedCopy := *task.CompletedAt
		task.CompletedAt = &completedCopy
	}
	if task.NextRetryAt != nil {
		retryCopy := *task.NextRetryAt
		task.NextRetryAt = &retryCopy
	}
	return task
}

var _ TaskService = (*Manager)(nil)
