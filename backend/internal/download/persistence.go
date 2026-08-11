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
