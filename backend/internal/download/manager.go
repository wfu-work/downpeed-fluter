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
	btTransfer         BTTransfer
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

	mu            sync.RWMutex
	tasks         map[string]Task
	requests      map[string]TransferRequest
	btRequests    map[string]BTTransferRequest
	btDiagnostics map[string]BTDiagnostics
	runs          map[string]*taskRun
	queue         []string

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
		btTransfer:         managerConfig.btTransfer,
		rootCtx:            rootCtx,
		stop:               stop,
		store:              store,
		maxConcurrentTasks: managerConfig.maxConcurrentTasks,
		maxRetries:         managerConfig.maxRetries,
		retryBaseDelay:     managerConfig.retryBaseDelay,
		limiter:            NewBandwidthLimiter(managerConfig.downloadRateLimit),
		tasks:              make(map[string]Task),
		requests:           make(map[string]TransferRequest),
		btRequests:         make(map[string]BTTransferRequest),
		btDiagnostics:      make(map[string]BTDiagnostics),
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

func (m *Manager) CreateBT(ctx context.Context, input CreateBTTaskRequest) (Task, error) {
	if m.btTransfer == nil {
		return Task{}, ErrUnsupportedProtocol
	}
	prepared, err := m.btTransfer.Prepare(ctx, input)
	if err != nil {
		return Task{}, err
	}
	prepared.Policy, err = normalizeBTPolicySettings(prepared.Policy)
	if err != nil {
		return Task{}, err
	}
	m.operationMu.Lock()
	defer m.operationMu.Unlock()
	if m.closed {
		return Task{}, ErrTaskInvalidState
	}
	directory := filepath.Clean(prepared.SaveDirectory)
	destination := filepath.Join(directory, prepared.Name)
	if _, err = os.Lstat(destination); err == nil {
		return Task{}, ErrDestinationExists
	} else if !errors.Is(err, os.ErrNotExist) {
		return Task{}, fmt.Errorf("%w: destination cannot be checked", ErrInvalidDestination)
	}
	now := time.Now().UTC()
	task := Task{
		ID:            fmt.Sprintf("%x-%x", now.UnixMilli(), m.sequence.Add(1)),
		Protocol:      ProtocolBT,
		URL:           "bt://" + prepared.Identity,
		FinalURL:      "bt://" + prepared.Identity,
		FileName:      prepared.Name,
		SaveDirectory: directory,
		FilePath:      destination,
		State:         TaskStateQueued,
		Total:         prepared.Total,
		CreatedAt:     now,
		UpdatedAt:     now,
	}
	m.mu.Lock()
	for _, existing := range m.tasks {
		if existing.FilePath == destination && !isTerminalState(existing.State) {
			m.mu.Unlock()
			return Task{}, ErrDestinationExists
		}
	}
	m.tasks[task.ID] = task
	m.btRequests[task.ID] = cloneBTTransferRequest(prepared)
	m.btDiagnostics[task.ID] = newBTDiagnostics(task, prepared)
	if err = m.persistTaskLocked(task); err != nil {
		delete(m.tasks, task.ID)
		delete(m.btRequests, task.ID)
		delete(m.btDiagnostics, task.ID)
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
		Protocol:      ProtocolHTTP,
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

func (m *Manager) GetBTDiagnostics(_ context.Context, id string) (BTDiagnostics, error) {
	m.mu.RLock()
	task, ok := m.tasks[id]
	if !ok {
		m.mu.RUnlock()
		return BTDiagnostics{}, ErrTaskNotFound
	}
	if task.Protocol != ProtocolBT {
		m.mu.RUnlock()
		return BTDiagnostics{}, ErrUnsupportedProtocol
	}
	diagnostics, ok := m.btDiagnostics[id]
	request := m.btRequests[id]
	m.mu.RUnlock()
	if !ok {
		diagnostics = newBTDiagnostics(task, request)
	}
	diagnostics.TaskID = task.ID
	diagnostics.State = task.State
	diagnostics.Live = task.State == TaskStateDownloading && diagnostics.Live
	diagnostics.Connections.Configured = len(request.ExplicitPeers)
	return cloneBTDiagnostics(diagnostics), nil
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
	task.Connections = 0
	task.NextRetryAt = nil
	task.UpdatedAt = time.Now().UTC()
	task.CompletedAt = nil
	m.tasks[id] = task
	m.markBTDiagnosticsStoppedLocked(task)
	_ = m.persistTaskLocked(task)
	m.mu.Unlock()
	if run == nil {
		m.publish(task)
		return cloneTask(task), nil
	}

	run.cancel(ErrTransferPaused)
	<-run.done

	if task.Protocol == ProtocolBT {
		m.publish(task)
		return cloneTask(task), nil
	}
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
	if task.Protocol == ProtocolBT {
		if _, ok := m.btRequests[id]; !ok {
			m.mu.Unlock()
			return Task{}, ErrTaskInvalidState
		}
		m.mu.Unlock()
		return m.resumeBTLocked(id)
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

func (m *Manager) Retry(ctx context.Context, id string) (Task, error) {
	m.operationMu.Lock()
	defer m.operationMu.Unlock()
	if m.closed {
		return Task{}, ErrTaskInvalidState
	}

	m.mu.RLock()
	task, ok := m.tasks[id]
	request, hasRequest := m.requests[id]
	btRequest, hasBTRequest := m.btRequests[id]
	m.mu.RUnlock()
	if !ok {
		return Task{}, ErrTaskNotFound
	}
	if task.State != TaskStateFailed {
		return Task{}, ErrTaskInvalidState
	}
	if task.Error == nil || !task.Error.Retryable {
		return Task{}, ErrTaskRetryNotAllowed
	}
	if _, err := os.Lstat(task.FilePath); err == nil {
		return Task{}, ErrDestinationExists
	} else if !errors.Is(err, os.ErrNotExist) {
		return Task{}, fmt.Errorf("%w: destination cannot be checked", ErrInvalidDestination)
	}

	downloaded := int64(0)
	if task.Protocol == ProtocolBT {
		if !hasBTRequest || m.btTransfer == nil {
			return Task{}, ErrTaskInvalidState
		}
		if err := m.btTransfer.Cleanup(ctx, btRequest); err != nil {
			return Task{}, err
		}
	} else {
		if !hasRequest {
			return Task{}, ErrTaskInvalidState
		}
		var err error
		request, downloaded, err = m.prepareHTTPRetry(request, task.Total)
		if err != nil {
			return Task{}, err
		}
	}

	m.mu.Lock()
	task = m.tasks[id]
	if task.State != TaskStateFailed || task.Error == nil || !task.Error.Retryable {
		m.mu.Unlock()
		return Task{}, ErrTaskInvalidState
	}
	previousTask := cloneTask(task)
	previousRequest := m.requests[id]
	task.State = TaskStateQueued
	task.Downloaded = downloaded
	task.SpeedBPS = 0
	task.Connections = 0
	task.Error = nil
	task.RetryCount = 0
	task.NextRetryAt = nil
	task.CompletedAt = nil
	task.UpdatedAt = time.Now().UTC()
	m.tasks[id] = task
	if task.Protocol == ProtocolBT {
		m.btDiagnostics[id] = newBTDiagnostics(task, btRequest)
	} else {
		request.Offset = downloaded
		request.ExpectedSize = task.Total
		request.Limiter = m.limiter
		m.requests[id] = request
	}
	if err := m.persistTaskLocked(task); err != nil {
		m.tasks[id] = previousTask
		if task.Protocol != ProtocolBT {
			m.requests[id] = previousRequest
		}
		m.markBTDiagnosticsStoppedLocked(previousTask)
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

func (m *Manager) prepareHTTPRetry(request TransferRequest, total int64) (TransferRequest, int64, error) {
	if request.Checkpoint != nil || request.AllowSegments {
		if err := os.Remove(request.WorkPath); err != nil && !errors.Is(err, os.ErrNotExist) {
			return TransferRequest{}, 0, fmt.Errorf("%w: partial file cannot be replaced", ErrInvalidDestination)
		}
		request.Checkpoint = nil
		return request, 0, nil
	}

	downloaded, err := partialFileSize(request.WorkPath)
	if err != nil {
		return TransferRequest{}, 0, err
	}
	if total > 0 && downloaded > total {
		return TransferRequest{}, 0, ErrPartialFileChanged
	}
	if downloaded > 0 && request.Validator.IfRangeValue() == "" {
		if err = os.Remove(request.WorkPath); err != nil && !errors.Is(err, os.ErrNotExist) {
			return TransferRequest{}, 0, fmt.Errorf("%w: partial file cannot be replaced", ErrInvalidDestination)
		}
		downloaded = 0
	}
	request.Checkpoint = nil
	return request, downloaded, nil
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
	btRequest := m.btRequests[id]
	m.removeFromQueueLocked(id)
	request.Checkpoint = nil
	m.requests[id] = request
	now := time.Now().UTC()
	task.State = TaskStateCanceled
	task.SpeedBPS = 0
	task.Connections = 0
	task.NextRetryAt = nil
	task.UpdatedAt = now
	task.CompletedAt = &now
	m.tasks[id] = task
	m.markBTDiagnosticsStoppedLocked(task)
	persistErr := m.persistTaskLocked(task)
	m.mu.Unlock()
	if run != nil {
		run.cancel(ErrTransferCanceled)
		<-run.done
	}
	if task.Protocol == ProtocolBT {
		_ = m.btTransfer.Cleanup(context.Background(), btRequest)
	} else {
		_ = os.Remove(request.WorkPath)
	}
	if persistErr != nil {
		return Task{}, persistErr
	}
	m.publish(task)
	return cloneTask(task), nil
}

func (m *Manager) Delete(ctx context.Context, id string, deleteFile bool) (DeleteTaskResult, error) {
	m.operationMu.Lock()
	defer m.operationMu.Unlock()
	if m.closed {
		return DeleteTaskResult{}, ErrTaskInvalidState
	}

	m.mu.RLock()
	task, ok := m.tasks[id]
	m.mu.RUnlock()
	if !ok {
		return DeleteTaskResult{}, ErrTaskNotFound
	}
	if task.State != TaskStateCompleted && task.State != TaskStateFailed && task.State != TaskStateCanceled {
		return DeleteTaskResult{}, ErrTaskInvalidState
	}

	fileDeleted := false
	if deleteFile && task.State == TaskStateCompleted {
		info, err := os.Lstat(task.FilePath)
		switch {
		case errors.Is(err, os.ErrNotExist):
		case err != nil:
			return DeleteTaskResult{}, fmt.Errorf("%w: destination cannot be inspected", ErrTaskFileDelete)
		case task.Protocol == ProtocolBT && (info.Mode().IsRegular() || info.IsDir()):
			err = removeBTOutput(task)
			if err != nil {
				return DeleteTaskResult{}, fmt.Errorf("%w: remove destination", ErrTaskFileDelete)
			}
			fileDeleted = true
		case info.Mode().IsRegular():
			if task.Protocol == ProtocolBT {
				err = removeBTOutput(task)
			} else {
				err = os.Remove(task.FilePath)
			}
			if err != nil {
				return DeleteTaskResult{}, fmt.Errorf("%w: remove destination", ErrTaskFileDelete)
			}
			fileDeleted = true
		default:
			return DeleteTaskResult{}, fmt.Errorf("%w: destination is not a supported task output", ErrTaskFileDelete)
		}
	}

	if m.store != nil {
		if err := m.store.Delete(ctx, id); err != nil {
			return DeleteTaskResult{}, fmt.Errorf("%w: %v", ErrTaskPersistence, err)
		}
	}
	m.mu.Lock()
	delete(m.tasks, id)
	delete(m.requests, id)
	delete(m.btRequests, id)
	delete(m.btDiagnostics, id)
	m.removeFromQueueLocked(id)
	m.mu.Unlock()
	m.publishEvent(TaskRemovedEvent, task)
	return DeleteTaskResult{ID: id, FileDeleted: fileDeleted}, nil
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
				task.Connections = 0
				task.NextRetryAt = nil
				task.CompletedAt = nil
				task.UpdatedAt = time.Now().UTC()
				m.tasks[id] = task
				m.markBTDiagnosticsStoppedLocked(task)
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
			if task.Protocol == ProtocolBT {
				if err := m.persistTaskLocked(task); err != nil && m.closeErr == nil {
					m.closeErr = err
				}
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

func (m *Manager) startBTRunLocked(id string, request BTTransferRequest) {
	transferCtx, cancel := context.WithCancelCause(m.rootCtx)
	run := &taskRun{cancel: cancel, done: make(chan struct{})}
	m.runs[id] = run
	go m.runBT(transferCtx, id, request, run)
}

func (m *Manager) runBT(ctx context.Context, id string, request BTTransferRequest, run *taskRun) {
	defer close(run.done)
	result, err := m.btTransfer.Download(ctx, request, func(progress BTTransferProgress) {
		m.mu.Lock()
		task, ok := m.tasks[id]
		if !ok || task.State != TaskStateDownloading || m.runs[id] != run {
			m.mu.Unlock()
			return
		}
		task.Downloaded = progress.Downloaded
		task.Total = progress.Total
		task.SpeedBPS = progress.SpeedBPS
		task.Connections = progress.Connections
		task.UpdatedAt = time.Now().UTC()
		m.tasks[id] = task
		diagnostics := cloneBTDiagnostics(progress.Diagnostics)
		diagnostics.TaskID = id
		diagnostics.State = task.State
		diagnostics.Live = true
		diagnostics.Connections.Configured = len(request.ExplicitPeers)
		diagnostics.Policy = btPolicyDiagnostics(request.Policy)
		if diagnostics.UpdatedAt.IsZero() {
			diagnostics.UpdatedAt = task.UpdatedAt
		}
		m.btDiagnostics[id] = diagnostics
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
	task.Connections = 0
	delete(m.runs, id)
	if err == nil {
		task.State = TaskStateCompleted
		task.Downloaded = result.Size
		task.Total = result.Size
		task.Error = nil
		task.CompletedAt = &now
	} else if errors.Is(err, context.Canceled) {
		task.State = TaskStateCanceled
		task.CompletedAt = &now
	} else {
		task.State = TaskStateFailed
		task.Error = taskErrorFor(err)
		task.CompletedAt = &now
		_ = m.btTransfer.Cleanup(context.Background(), request)
	}
	m.tasks[id] = task
	m.markBTDiagnosticsStoppedLocked(task)
	_ = m.persistTaskLocked(task)
	updates := m.fillAvailableSlotsLocked()
	m.mu.Unlock()
	m.publish(task)
	for _, update := range updates {
		m.publish(update)
	}
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
	m.publishEvent(TaskUpdatedEvent, task)
}

func (m *Manager) publishEvent(eventType string, task Task) {
	event := TaskEvent{Type: eventType, Task: cloneTask(task)}
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

func cloneBTTransferRequest(request BTTransferRequest) BTTransferRequest {
	request.Metadata = append([]byte(nil), request.Metadata...)
	request.SelectedFileIndexes = append([]int(nil), request.SelectedFileIndexes...)
	request.ExplicitPeers = append([]string(nil), request.ExplicitPeers...)
	request.Files = append([]BTFile(nil), request.Files...)
	return request
}

func newBTDiagnostics(task Task, request BTTransferRequest) BTDiagnostics {
	return BTDiagnostics{
		TaskID: task.ID,
		State:  task.State,
		Connections: BTConnectionDiagnostics{
			Configured: len(request.ExplicitPeers),
		},
		Peers:     make([]BTPeerDiagnostics, 0),
		Policy:    btPolicyDiagnostics(request.Policy),
		UpdatedAt: task.UpdatedAt,
	}
}

func btPolicyDiagnostics(policy BTPolicySettings) BTPolicyDiagnostics {
	return BTPolicyDiagnostics{
		MaxPeerConnections: policy.MaxPeerConnections,
		ExplicitPeersOnly:  policy.ExplicitPeersOnly,
		TrackersEnabled:    policy.TrackersEnabled,
		DHTEnabled:         policy.DHTEnabled,
		PEXEnabled:         policy.PEXEnabled,
		WebSeedsEnabled:    policy.WebSeedsEnabled,
		InboundEnabled:     policy.InboundEnabled,
		IPv6Enabled:        policy.IPv6Enabled,
		UploadEnabled:      policy.UploadEnabled,
		SeedingEnabled:     policy.SeedingEnabled,
	}
}

func cloneBTDiagnostics(value BTDiagnostics) BTDiagnostics {
	value.Peers = append([]BTPeerDiagnostics(nil), value.Peers...)
	return value
}

func (m *Manager) markBTDiagnosticsStoppedLocked(task Task) {
	if task.Protocol != ProtocolBT {
		return
	}
	diagnostics, ok := m.btDiagnostics[task.ID]
	if !ok {
		diagnostics = newBTDiagnostics(task, m.btRequests[task.ID])
	}
	diagnostics.State = task.State
	diagnostics.Live = false
	diagnostics.Connections.Connected = 0
	diagnostics.Connections.HalfOpen = 0
	diagnostics.Connections.Seeders = 0
	diagnostics.Peers = nil
	diagnostics.UpdatedAt = task.UpdatedAt
	m.btDiagnostics[task.ID] = diagnostics
}

func isTerminalState(state TaskState) bool {
	return state == TaskStateCompleted || state == TaskStateFailed || state == TaskStateCanceled
}

func (m *Manager) resumeBTLocked(id string) (Task, error) {
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
	if _, err := os.Lstat(task.FilePath); err == nil {
		m.mu.Unlock()
		return Task{}, ErrDestinationExists
	} else if !errors.Is(err, os.ErrNotExist) {
		m.mu.Unlock()
		return Task{}, ErrInvalidDestination
	}
	task.State = TaskStateQueued
	task.SpeedBPS = 0
	task.Connections = 0
	task.Error = nil
	task.NextRetryAt = nil
	task.CompletedAt = nil
	task.UpdatedAt = time.Now().UTC()
	m.tasks[id] = task
	m.btDiagnostics[id] = newBTDiagnostics(task, m.btRequests[id])
	if err := m.persistTaskLocked(task); err != nil {
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

func removeBTOutput(task Task) error {
	if task.Protocol != ProtocolBT || !filepath.IsAbs(task.SaveDirectory) || task.FilePath != filepath.Join(task.SaveDirectory, task.FileName) {
		return ErrTaskFileDelete
	}
	info, err := os.Lstat(task.FilePath)
	if err != nil {
		return err
	}
	if info.Mode()&os.ModeSymlink != 0 {
		return ErrTaskFileDelete
	}
	return os.RemoveAll(task.FilePath)
}

var _ TaskService = (*Manager)(nil)
var _ BTTaskCreator = (*Manager)(nil)
var _ BTDiagnosticsService = (*Manager)(nil)
