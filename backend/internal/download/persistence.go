package download

import (
	"context"
	"errors"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"time"
)

func (m *Manager) restore(ctx context.Context) error {
	records, err := m.store.Load(ctx)
	if err != nil {
		return err
	}
	for _, record := range records {
		if record.Task.Protocol == ProtocolBT {
			task, request, reconcileErr := reconcileStoredBTTask(record)
			if reconcileErr != nil {
				return reconcileErr
			}
			if _, exists := m.tasks[task.ID]; exists {
				return fmt.Errorf("%w: duplicate task ID", ErrTaskPersistence)
			}
			m.tasks[task.ID] = task
			m.btRequests[task.ID] = request
			m.btDiagnostics[task.ID] = newBTDiagnostics(task, request)
			if err = m.store.Save(ctx, storedBTTask(task, request)); err != nil {
				return err
			}
			continue
		}
		task, request, reconcileErr := reconcileStoredTask(record)
		if reconcileErr != nil {
			return reconcileErr
		}
		if _, exists := m.tasks[task.ID]; exists {
			return fmt.Errorf("%w: duplicate task ID", ErrTaskPersistence)
		}
		m.tasks[task.ID] = task
		m.requests[task.ID] = request
		if err = m.store.Save(ctx, StoredTask{
			Task:         cloneTask(task),
			Headers:      cloneHeaders(request.Headers),
			AcceptRanges: request.AcceptRanges,
			Validator:    request.Validator,
			Checkpoint:   CloneTransferCheckpoint(request.Checkpoint),
		}); err != nil {
			return err
		}
	}
	return nil
}

func reconcileStoredTask(record StoredTask) (Task, TransferRequest, error) {
	task := cloneTask(record.Task)
	if task.Protocol == "" {
		task.Protocol = ProtocolHTTP
	}
	if err := validateStoredTask(task); err != nil {
		return Task{}, TransferRequest{}, err
	}
	validator, err := NormalizeResourceValidator(record.Validator.ETag, record.Validator.LastModified)
	if err != nil {
		return Task{}, TransferRequest{}, fmt.Errorf("%w: stored resource validator is invalid", ErrTaskPersistence)
	}
	request := TransferRequest{
		URL:           task.URL,
		Headers:       cloneHeaders(record.Headers),
		Destination:   task.FilePath,
		WorkPath:      temporaryPath(task.FilePath),
		ExpectedSize:  task.Total,
		AcceptRanges:  record.AcceptRanges,
		AllowSegments: (record.AcceptRanges && task.Total >= DefaultSegmentedTransferMinSize) || record.Checkpoint != nil,
		Validator:     validator,
		Checkpoint:    CloneTransferCheckpoint(record.Checkpoint),
	}

	switch task.State {
	case TaskStateDownloading, TaskStateQueued, TaskStateRetrying, TaskStatePaused:
		reconcileInterruptedTask(&task, &request)
	case TaskStateCompleted:
		task.SpeedBPS = 0
		task.NextRetryAt = nil
		request.Checkpoint = nil
		_ = os.Remove(request.WorkPath)
	case TaskStateFailed, TaskStateCanceled:
		task.SpeedBPS = 0
		task.NextRetryAt = nil
		request.Checkpoint = nil
		_ = os.Remove(request.WorkPath)
	default:
		return Task{}, TransferRequest{}, fmt.Errorf("%w: unknown task state %q", ErrTaskPersistence, task.State)
	}
	if request.Checkpoint == nil && request.Validator.IfRangeValue() == "" {
		request.AllowSegments = false
	}
	return task, request, nil
}

func validateStoredTask(task Task) error {
	if task.Protocol != ProtocolHTTP {
		return fmt.Errorf("%w: stored task protocol is invalid", ErrTaskPersistence)
	}
	parsedURL, err := url.ParseRequestURI(task.URL)
	if err != nil || parsedURL.Host == "" || (parsedURL.Scheme != "http" && parsedURL.Scheme != "https") {
		return fmt.Errorf("%w: stored task URL is invalid", ErrTaskPersistence)
	}
	if task.ID == "" || task.FileName != SafeFileName(task.FileName) || task.FileName == "" {
		return fmt.Errorf("%w: stored task identity is invalid", ErrTaskPersistence)
	}
	directory := filepath.Clean(task.SaveDirectory)
	if !filepath.IsAbs(directory) || task.FilePath != filepath.Join(directory, task.FileName) {
		return fmt.Errorf("%w: stored task destination is invalid", ErrTaskPersistence)
	}
	if task.Downloaded < 0 || task.Total < -1 || task.SpeedBPS < 0 || task.RetryCount < 0 || task.CreatedAt.IsZero() || task.UpdatedAt.IsZero() {
		return fmt.Errorf("%w: stored task progress is invalid", ErrTaskPersistence)
	}
	return nil
}

func reconcileInterruptedTask(task *Task, request *TransferRequest) {
	now := time.Now().UTC()
	task.State = TaskStatePaused
	task.SpeedBPS = 0
	task.NextRetryAt = nil
	task.CompletedAt = nil
	task.UpdatedAt = now

	finalInfo, finalErr := os.Lstat(task.FilePath)
	workInfo, workErr := os.Lstat(request.WorkPath)
	if finalErr == nil {
		if finalInfo.Mode().IsRegular() && completedFileMatches(*task, finalInfo, workInfo, workErr) {
			task.State = TaskStateCompleted
			task.Downloaded = finalInfo.Size()
			task.Total = finalInfo.Size()
			task.CompletedAt = &now
			task.Error = nil
			request.Checkpoint = nil
			_ = os.Remove(request.WorkPath)
			return
		}
		markRecoveredTaskFailed(task, "destination_exists", "A file already exists at the selected destination.")
		request.Checkpoint = nil
		_ = os.Remove(request.WorkPath)
		return
	}
	if !errors.Is(finalErr, os.ErrNotExist) {
		markRecoveredTaskFailed(task, "invalid_destination", "The selected download destination is unavailable.")
		return
	}

	if errors.Is(workErr, os.ErrNotExist) {
		if task.Downloaded > 0 || request.Checkpoint != nil {
			markRecoveredTaskFailed(task, "partial_file_changed", "The partial download file is missing.")
			request.Checkpoint = nil
		} else {
			task.Downloaded = 0
			task.Error = nil
		}
		return
	}
	if workErr != nil || !workInfo.Mode().IsRegular() {
		markRecoveredTaskFailed(task, "partial_file_changed", "The partial download file changed outside Downpeed.")
		request.Checkpoint = nil
		return
	}
	if request.Checkpoint != nil {
		downloaded, err := ValidateTransferCheckpoint(request.Checkpoint, task.Total)
		if err != nil || workInfo.Size() != request.Checkpoint.Total {
			markRecoveredTaskFailed(task, "partial_file_changed", "The segmented download checkpoint or partial file changed outside Downpeed.")
			request.Checkpoint = nil
			return
		}
		task.Downloaded = downloaded
		task.Total = request.Checkpoint.Total
		task.Error = nil
		return
	}
	if request.AllowSegments {
		if task.Downloaded == 0 {
			_ = os.Remove(request.WorkPath)
			if request.Validator.IfRangeValue() == "" {
				request.AllowSegments = false
			}
			task.Error = nil
			return
		}
		markRecoveredTaskFailed(task, "partial_file_changed", "The segmented download checkpoint is missing.")
		_ = os.Remove(request.WorkPath)
		return
	}
	if task.Total > 0 && workInfo.Size() > task.Total {
		markRecoveredTaskFailed(task, "partial_file_changed", "The partial download file changed outside Downpeed.")
		return
	}
	task.Downloaded = workInfo.Size()
	task.Error = nil
}

func completedFileMatches(task Task, finalInfo os.FileInfo, workInfo os.FileInfo, workErr error) bool {
	if task.Total > 0 {
		return finalInfo.Size() == task.Total
	}
	if workErr == nil && workInfo.Mode().IsRegular() {
		return os.SameFile(finalInfo, workInfo)
	}
	return false
}

func markRecoveredTaskFailed(task *Task, code, message string) {
	now := task.UpdatedAt
	task.State = TaskStateFailed
	task.SpeedBPS = 0
	task.CompletedAt = &now
	task.Error = &TaskError{Code: code, Message: message, Retryable: false}
}

func (m *Manager) persistTaskLocked(task Task) error {
	if m.store == nil {
		return nil
	}
	if task.Protocol == ProtocolBT {
		return m.persistBTTaskLocked(task)
	}
	request := m.requests[task.ID]
	if err := m.store.Save(context.Background(), StoredTask{
		Task:         cloneTask(task),
		Headers:      cloneHeaders(request.Headers),
		AcceptRanges: request.AcceptRanges,
		Validator:    request.Validator,
		Checkpoint:   CloneTransferCheckpoint(request.Checkpoint),
	}); err != nil {
		return fmt.Errorf("%w: %v", ErrTaskPersistence, err)
	}
	return nil
}

func reconcileStoredBTTask(record StoredTask) (Task, BTTransferRequest, error) {
	if record.BT == nil {
		return Task{}, BTTransferRequest{}, fmt.Errorf("%w: BT task state is missing", ErrTaskPersistence)
	}
	task := cloneTask(record.Task)
	if task.Protocol != ProtocolBT || task.ID == "" || task.FileName == "" || task.FileName != SafeFileName(task.FileName) {
		return Task{}, BTTransferRequest{}, fmt.Errorf("%w: BT task identity is invalid", ErrTaskPersistence)
	}
	if !filepath.IsAbs(task.SaveDirectory) || task.FilePath != filepath.Join(task.SaveDirectory, task.FileName) {
		return Task{}, BTTransferRequest{}, fmt.Errorf("%w: BT destination is invalid", ErrTaskPersistence)
	}
	if len(record.BT.Metadata) == 0 || len(record.BT.Metadata) > MaxTorrentMetadataBytes || record.BT.Identity == "" || record.BT.Total < 0 {
		return Task{}, BTTransferRequest{}, fmt.Errorf("%w: BT protocol state is invalid", ErrTaskPersistence)
	}
	request := BTTransferRequest{
		Metadata: append([]byte(nil), record.BT.Metadata...), SaveDirectory: task.SaveDirectory,
		Name: record.BT.Name, Identity: record.BT.Identity, Total: record.BT.Total,
		SelectedFileIndexes: append([]int(nil), record.BT.SelectedFileIndexes...),
		ExplicitPeers:       append([]string(nil), record.BT.ExplicitPeers...), Files: append([]BTFile(nil), record.BT.Files...),
		Policy: record.BT.Policy,
	}
	if request.Policy == (BTPolicySettings{}) {
		request.Policy = DefaultBTPolicySettings()
	}
	if _, err := normalizeBTPolicySettings(request.Policy); err != nil {
		return Task{}, BTTransferRequest{}, fmt.Errorf("%w: stored BT policy is invalid", ErrTaskPersistence)
	}
	now := time.Now().UTC()
	if task.State == TaskStateDownloading || task.State == TaskStateQueued || task.State == TaskStateRetrying {
		task.State = TaskStatePaused
		task.SpeedBPS = 0
		task.Connections = 0
		task.NextRetryAt = nil
		task.CompletedAt = nil
		task.UpdatedAt = now
	}
	if task.State != TaskStatePaused && !isTerminalState(task.State) {
		return Task{}, BTTransferRequest{}, fmt.Errorf("%w: unknown BT task state", ErrTaskPersistence)
	}
	return task, request, nil
}

func storedBTTask(task Task, request BTTransferRequest) StoredTask {
	return StoredTask{Task: cloneTask(task), BT: &StoredBTTask{
		Metadata: append([]byte(nil), request.Metadata...), Name: request.Name, Identity: request.Identity, Total: request.Total,
		Files: append([]BTFile(nil), request.Files...), SelectedFileIndexes: append([]int(nil), request.SelectedFileIndexes...),
		ExplicitPeers: append([]string(nil), request.ExplicitPeers...),
		Policy:        request.Policy,
	}}
}

func (m *Manager) persistBTTaskLocked(task Task) error {
	request, ok := m.btRequests[task.ID]
	if !ok {
		return fmt.Errorf("%w: BT transfer state is missing", ErrTaskPersistence)
	}
	if err := m.store.Save(context.Background(), storedBTTask(task, request)); err != nil {
		return fmt.Errorf("%w: %v", ErrTaskPersistence, err)
	}
	return nil
}
