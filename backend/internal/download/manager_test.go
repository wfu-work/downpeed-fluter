package download

import (
	"bytes"
	"context"
	"errors"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"
)

func TestManagerCreatesAndCompletesTaskFromTransferProgress(t *testing.T) {
	directory := t.TempDir()
	manager := NewManager(context.Background(), transferFunc(func(
		_ context.Context,
		request TransferRequest,
		onProgress func(TransferProgress),
	) (TransferResult, error) {
		if request.Destination != filepath.Join(directory, "file.bin") {
			t.Errorf("destination = %q", request.Destination)
		}
		if request.WorkPath != filepath.Join(directory, ".file.bin.downpeed") {
			t.Errorf("work path = %q", request.WorkPath)
		}
		if request.Validator.ETag != `"release-v1"` {
			t.Errorf("validator = %#v", request.Validator)
		}
		onProgress(TransferProgress{Downloaded: 256, Total: 1024, SpeedBPS: 512})
		return TransferResult{FinalURL: "https://cdn.example.com/file.bin", Size: 1024}, nil
	}))
	defer manager.Close()
	subscriptionContext, cancelSubscription := context.WithCancel(context.Background())
	defer cancelSubscription()
	events := manager.Subscribe(subscriptionContext)

	task, err := manager.Create(context.Background(), CreateTaskRequest{
		URL:           "https://example.com/file.bin",
		FileName:      "file.bin",
		SaveDirectory: directory,
		ETag:          `"release-v1"`,
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	completed := waitForTaskState(t, manager, task.ID, TaskStateCompleted)
	if completed.Downloaded != 1024 || completed.Total != 1024 {
		t.Fatalf("completed task = %#v", completed)
	}
	if completed.FinalURL != "https://cdn.example.com/file.bin" {
		t.Fatalf("FinalURL = %q", completed.FinalURL)
	}
	select {
	case event := <-events:
		if event.Task.ID != task.ID {
			t.Fatalf("event task = %q", event.Task.ID)
		}
	case <-time.After(time.Second):
		t.Fatal("timed out waiting for task event")
	}
}

func TestManagerCancelsRunningTask(t *testing.T) {
	started := make(chan struct{})
	stopped := make(chan struct{})
	manager := NewManager(context.Background(), transferFunc(func(
		ctx context.Context,
		_ TransferRequest,
		_ func(TransferProgress),
	) (TransferResult, error) {
		close(started)
		<-ctx.Done()
		close(stopped)
		return TransferResult{}, ctx.Err()
	}))
	defer manager.Close()

	task, err := manager.Create(context.Background(), CreateTaskRequest{
		URL:           "https://example.com/large.bin",
		FileName:      "large.bin",
		SaveDirectory: t.TempDir(),
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	<-started
	canceled, err := manager.Cancel(context.Background(), task.ID)
	if err != nil {
		t.Fatalf("Cancel() error = %v", err)
	}
	if canceled.State != TaskStateCanceled || canceled.CompletedAt == nil {
		t.Fatalf("canceled task = %#v", canceled)
	}
	select {
	case <-stopped:
	case <-time.After(time.Second):
		t.Fatal("transfer context was not canceled")
	}
	if _, err = manager.Cancel(context.Background(), task.ID); !errors.Is(err, ErrTaskInvalidState) {
		t.Fatalf("second Cancel() error = %v", err)
	}
}

func TestManagerPausesAndResumesFromVerifiedPartialFile(t *testing.T) {
	directory := t.TempDir()
	firstStarted := make(chan struct{})
	manager := NewManager(context.Background(), transferFunc(func(
		ctx context.Context,
		request TransferRequest,
		onProgress func(TransferProgress),
	) (TransferResult, error) {
		if request.Offset == 0 {
			if err := os.WriteFile(request.WorkPath, []byte("down"), 0o644); err != nil {
				return TransferResult{}, err
			}
			onProgress(TransferProgress{Downloaded: 4, Total: 8, SpeedBPS: 4})
			close(firstStarted)
			<-ctx.Done()
			return TransferResult{}, ctx.Err()
		}
		if request.Offset != 4 {
			t.Fatalf("resume offset = %d, want 4", request.Offset)
		}
		file, err := os.OpenFile(request.WorkPath, os.O_WRONLY|os.O_APPEND, 0o644)
		if err != nil {
			return TransferResult{}, err
		}
		if err = os.Rename(request.WorkPath, request.Destination); err != nil {
			return TransferResult{}, err
		}
		_, err = file.WriteString("peed")
		_ = file.Close()
		if err != nil {
			return TransferResult{}, err
		}
		onProgress(TransferProgress{Downloaded: 8, Total: 8, SpeedBPS: 4})
		return TransferResult{FinalURL: request.URL, Size: 8}, nil
	}))
	defer manager.Close()

	task, err := manager.Create(context.Background(), CreateTaskRequest{
		URL:           "https://example.com/downpeed.bin",
		FileName:      "downpeed.bin",
		SaveDirectory: directory,
		ETag:          `"release-v1"`,
	})
	if err != nil {
		t.Fatal(err)
	}
	<-firstStarted
	paused, err := manager.Pause(context.Background(), task.ID)
	if err != nil {
		t.Fatalf("Pause() error = %v", err)
	}
	if paused.State != TaskStatePaused || paused.Downloaded != 4 || paused.SpeedBPS != 0 {
		t.Fatalf("paused task = %#v", paused)
	}
	partial, err := os.ReadFile(temporaryPath(paused.FilePath))
	if err != nil || !bytes.Equal(partial, []byte("down")) {
		t.Fatalf("partial file = %q, error = %v", partial, err)
	}

	resumed, err := manager.Resume(context.Background(), task.ID)
	if err != nil {
		t.Fatalf("Resume() error = %v", err)
	}
	if resumed.State != TaskStateDownloading {
		t.Fatalf("resumed state = %q", resumed.State)
	}
	completed := waitForTaskState(t, manager, task.ID, TaskStateCompleted)
	value, err := os.ReadFile(completed.FilePath)
	if err != nil || !bytes.Equal(value, []byte("downpeed")) {
		t.Fatalf("completed file = %q, error = %v", value, err)
	}
}

func TestManagerRejectsResumeWhenPartialFileChanged(t *testing.T) {
	started := make(chan struct{})
	manager := NewManager(context.Background(), transferFunc(func(
		ctx context.Context,
		request TransferRequest,
		onProgress func(TransferProgress),
	) (TransferResult, error) {
		if err := os.WriteFile(request.WorkPath, []byte("part"), 0o644); err != nil {
			return TransferResult{}, err
		}
		onProgress(TransferProgress{Downloaded: 4, Total: 8})
		close(started)
		<-ctx.Done()
		return TransferResult{}, ctx.Err()
	}))
	defer manager.Close()
	task, err := manager.Create(context.Background(), CreateTaskRequest{
		URL:           "https://example.com/file.bin",
		FileName:      "file.bin",
		SaveDirectory: t.TempDir(),
	})
	if err != nil {
		t.Fatal(err)
	}
	<-started
	paused, err := manager.Pause(context.Background(), task.ID)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(temporaryPath(paused.FilePath), []byte("changed"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err = manager.Resume(context.Background(), task.ID); !errors.Is(err, ErrPartialFileChanged) {
		t.Fatalf("Resume() error = %v, want ErrPartialFileChanged", err)
	}
	canceled, err := manager.Cancel(context.Background(), task.ID)
	if err != nil {
		t.Fatalf("Cancel() paused task error = %v", err)
	}
	if canceled.State != TaskStateCanceled {
		t.Fatalf("canceled state = %q", canceled.State)
	}
	if _, err = os.Stat(temporaryPath(paused.FilePath)); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("canceled paused file still exists: %v", err)
	}
}

func TestManagerRejectsExistingDestinationBeforeStarting(t *testing.T) {
	directory := t.TempDir()
	if err := os.WriteFile(filepath.Join(directory, "keep.bin"), []byte("keep"), 0o644); err != nil {
		t.Fatal(err)
	}
	called := false
	manager := NewManager(context.Background(), transferFunc(func(
		context.Context,
		TransferRequest,
		func(TransferProgress),
	) (TransferResult, error) {
		called = true
		return TransferResult{}, nil
	}))
	defer manager.Close()

	_, err := manager.Create(context.Background(), CreateTaskRequest{
		URL:           "https://example.com/keep.bin",
		FileName:      "keep.bin",
		SaveDirectory: directory,
	})
	if !errors.Is(err, ErrDestinationExists) {
		t.Fatalf("Create() error = %v, want ErrDestinationExists", err)
	}
	if called {
		t.Fatal("transfer started for an existing destination")
	}
}

func TestManagerRejectsExistingTemporaryFileBeforeStarting(t *testing.T) {
	directory := t.TempDir()
	if err := os.WriteFile(filepath.Join(directory, ".keep.bin.downpeed"), []byte("partial"), 0o644); err != nil {
		t.Fatal(err)
	}
	called := false
	manager := NewManager(context.Background(), transferFunc(func(
		context.Context,
		TransferRequest,
		func(TransferProgress),
	) (TransferResult, error) {
		called = true
		return TransferResult{}, nil
	}))
	defer manager.Close()

	_, err := manager.Create(context.Background(), CreateTaskRequest{
		URL:           "https://example.com/keep.bin",
		FileName:      "keep.bin",
		SaveDirectory: directory,
	})
	if !errors.Is(err, ErrDestinationExists) {
		t.Fatalf("Create() error = %v, want ErrDestinationExists", err)
	}
	if called {
		t.Fatal("transfer started for an existing temporary file")
	}
}

func TestPersistentManagerRestoresInterruptedTaskAsPausedAndResumes(t *testing.T) {
	directory := t.TempDir()
	store := newMemoryTaskStore()
	started := make(chan struct{})
	firstTransfer := transferFunc(func(
		ctx context.Context,
		request TransferRequest,
		onProgress func(TransferProgress),
	) (TransferResult, error) {
		if err := os.WriteFile(request.WorkPath, []byte("down"), 0o644); err != nil {
			return TransferResult{}, err
		}
		onProgress(TransferProgress{Downloaded: 4, Total: 8, SpeedBPS: 4})
		close(started)
		<-ctx.Done()
		if !errors.Is(context.Cause(ctx), ErrTransferShutdown) {
			t.Errorf("shutdown cause = %v", context.Cause(ctx))
		}
		return TransferResult{}, ctx.Err()
	})
	manager, err := NewPersistentManager(context.Background(), firstTransfer, store)
	if err != nil {
		t.Fatal(err)
	}
	task, err := manager.Create(context.Background(), CreateTaskRequest{
		URL:           "https://example.com/downpeed.bin",
		FileName:      "downpeed.bin",
		SaveDirectory: directory,
		Headers:       map[string]string{"X-Resume-Token": "secret"},
		ETag:          `"release-v1"`,
	})
	if err != nil {
		t.Fatal(err)
	}
	<-started
	if err = manager.Close(); err != nil {
		t.Fatal(err)
	}

	resumeCalls := 0
	secondTransfer := transferFunc(func(
		_ context.Context,
		request TransferRequest,
		onProgress func(TransferProgress),
	) (TransferResult, error) {
		resumeCalls++
		if request.Offset != 4 || request.Headers["X-Resume-Token"] != "secret" || request.Validator.ETag != `"release-v1"` {
			t.Fatalf("restored request = %#v", request)
		}
		file, openErr := os.OpenFile(request.WorkPath, os.O_WRONLY|os.O_APPEND, 0o644)
		if openErr != nil {
			return TransferResult{}, openErr
		}
		_, writeErr := file.WriteString("peed")
		_ = file.Close()
		if writeErr != nil {
			return TransferResult{}, writeErr
		}
		if renameErr := os.Rename(request.WorkPath, request.Destination); renameErr != nil {
			return TransferResult{}, renameErr
		}
		onProgress(TransferProgress{Downloaded: 8, Total: 8})
		return TransferResult{FinalURL: request.URL, Size: 8}, nil
	})
	restoredManager, err := NewPersistentManager(context.Background(), secondTransfer, store)
	if err != nil {
		t.Fatal(err)
	}
	defer restoredManager.Close()
	restored, err := restoredManager.Get(context.Background(), task.ID)
	if err != nil {
		t.Fatal(err)
	}
	if restored.State != TaskStatePaused || restored.Downloaded != 4 || resumeCalls != 0 {
		t.Fatalf("restored task = %#v, resume calls = %d", restored, resumeCalls)
	}
	if _, err = restoredManager.Resume(context.Background(), task.ID); err != nil {
		t.Fatal(err)
	}
	completed := waitForTaskState(t, restoredManager, task.ID, TaskStateCompleted)
	value, err := os.ReadFile(completed.FilePath)
	if err != nil || !bytes.Equal(value, []byte("downpeed")) {
		t.Fatalf("completed file = %q, error = %v", value, err)
	}
	if resumeCalls != 1 {
		t.Fatalf("resume calls = %d", resumeCalls)
	}
}

func TestPersistentManagerRefusesUnsafeLegacyResumeWithoutValidator(t *testing.T) {
	directory := t.TempDir()
	filePath := filepath.Join(directory, "legacy.bin")
	workPath := temporaryPath(filePath)
	if err := os.WriteFile(workPath, []byte("part"), 0o644); err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC()
	store := newMemoryTaskStore()
	store.records["legacy"] = StoredTask{
		Task: Task{
			ID: "legacy", URL: "https://example.com/legacy.bin", FinalURL: "https://example.com/legacy.bin",
			FileName: "legacy.bin", SaveDirectory: directory, FilePath: filePath,
			State: TaskStatePaused, Downloaded: 4, Total: 8, CreatedAt: now, UpdatedAt: now,
		},
		AcceptRanges: true,
	}
	manager, err := NewPersistentManager(context.Background(), transferFunc(func(
		context.Context,
		TransferRequest,
		func(TransferProgress),
	) (TransferResult, error) {
		t.Fatal("unsafe legacy transfer started")
		return TransferResult{}, nil
	}), store)
	if err != nil {
		t.Fatal(err)
	}
	defer manager.Close()

	if _, err = manager.Resume(context.Background(), "legacy"); !errors.Is(err, ErrResumeNotSupported) {
		t.Fatalf("Resume() error = %v, want ErrResumeNotSupported", err)
	}
	legacy, err := manager.Get(context.Background(), "legacy")
	if err != nil || legacy.State != TaskStatePaused || legacy.Downloaded != 4 {
		t.Fatalf("legacy task = %#v, error = %v", legacy, err)
	}
}

func TestPersistentManagerKeepsSegmentsDisabledForUntouchedLegacyTaskWithoutValidator(t *testing.T) {
	directory := t.TempDir()
	now := time.Now().UTC()
	store := newMemoryTaskStore()
	store.records["legacy"] = StoredTask{
		Task: Task{
			ID: "legacy", URL: "https://example.com/legacy.bin", FinalURL: "https://example.com/legacy.bin",
			FileName: "legacy.bin", SaveDirectory: directory, FilePath: filepath.Join(directory, "legacy.bin"),
			State: TaskStatePaused, Total: DefaultSegmentedTransferMinSize, CreatedAt: now, UpdatedAt: now,
		},
		AcceptRanges: true,
	}
	manager, err := NewPersistentManager(context.Background(), transferFunc(func(
		_ context.Context,
		request TransferRequest,
		_ func(TransferProgress),
	) (TransferResult, error) {
		if request.AllowSegments || request.Offset != 0 {
			t.Fatalf("unsafe restored request = %#v", request)
		}
		return TransferResult{FinalURL: request.URL, Size: request.ExpectedSize}, nil
	}), store)
	if err != nil {
		t.Fatal(err)
	}
	defer manager.Close()

	if _, err = manager.Resume(context.Background(), "legacy"); err != nil {
		t.Fatal(err)
	}
	waitForTaskState(t, manager, "legacy", TaskStateCompleted)
}

func TestPersistentManagerReconcilesPublishedAndMissingFiles(t *testing.T) {
	directory := t.TempDir()
	now := time.Now().UTC()
	completedPath := filepath.Join(directory, "completed.bin")
	if err := os.WriteFile(completedPath, []byte("done"), 0o644); err != nil {
		t.Fatal(err)
	}
	store := newMemoryTaskStore()
	store.records["published"] = StoredTask{Task: Task{
		ID: "published", URL: "https://example.com/completed.bin", FinalURL: "https://example.com/completed.bin",
		FileName: "completed.bin", SaveDirectory: directory, FilePath: completedPath,
		State: TaskStateDownloading, Downloaded: 4, Total: 4, CreatedAt: now, UpdatedAt: now,
	}}
	store.records["missing"] = StoredTask{Task: Task{
		ID: "missing", URL: "https://example.com/missing.bin", FinalURL: "https://example.com/missing.bin",
		FileName: "missing.bin", SaveDirectory: directory, FilePath: filepath.Join(directory, "missing.bin"),
		State: TaskStateDownloading, Downloaded: 4, Total: 8, CreatedAt: now, UpdatedAt: now,
	}}
	manager, err := NewPersistentManager(context.Background(), transferFunc(func(
		context.Context, TransferRequest, func(TransferProgress),
	) (TransferResult, error) {
		return TransferResult{}, errors.New("unexpected transfer")
	}), store)
	if err != nil {
		t.Fatal(err)
	}
	defer manager.Close()
	published, _ := manager.Get(context.Background(), "published")
	if published.State != TaskStateCompleted || published.CompletedAt == nil {
		t.Fatalf("published task = %#v", published)
	}
	missing, _ := manager.Get(context.Background(), "missing")
	if missing.State != TaskStateFailed || missing.Error == nil || missing.Error.Code != "partial_file_changed" {
		t.Fatalf("missing task = %#v", missing)
	}
}

func TestPersistentManagerRestoresSegmentCheckpointInsteadOfPreallocatedSize(t *testing.T) {
	directory := t.TempDir()
	filePath := filepath.Join(directory, "segmented.bin")
	workPath := temporaryPath(filePath)
	if err := os.WriteFile(workPath, nil, 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Truncate(workPath, 1024); err != nil {
		t.Fatal(err)
	}
	checkpoint := &TransferCheckpoint{
		Version: TransferCheckpointVersion,
		Total:   1024,
		Segments: []SegmentProgress{
			{Start: 0, End: 255, Completed: 100},
			{Start: 256, End: 511, Completed: 50},
			{Start: 512, End: 767, Completed: 0},
			{Start: 768, End: 1023, Completed: 0},
		},
	}
	now := time.Now().UTC()
	store := newMemoryTaskStore()
	store.records["segmented"] = StoredTask{
		Task: Task{
			ID: "segmented", URL: "https://example.com/segmented.bin", FinalURL: "https://example.com/segmented.bin",
			FileName: "segmented.bin", SaveDirectory: directory, FilePath: filePath,
			State: TaskStateDownloading, Downloaded: 150, Total: 1024, CreatedAt: now, UpdatedAt: now,
		},
		AcceptRanges: true,
		Validator:    ResourceValidator{ETag: `"release-v1"`},
		Checkpoint:   checkpoint,
	}
	resumeCalls := 0
	manager, err := NewPersistentManager(context.Background(), transferFunc(func(
		_ context.Context,
		request TransferRequest,
		_ func(TransferProgress),
	) (TransferResult, error) {
		resumeCalls++
		if request.Offset != 150 || request.ExpectedSize != 1024 || !request.AllowSegments {
			t.Fatalf("resume request = %#v", request)
		}
		if request.Checkpoint == nil || request.Checkpoint.Segments[0].Completed != 100 {
			t.Fatalf("resume checkpoint = %#v", request.Checkpoint)
		}
		if request.Validator.ETag != `"release-v1"` {
			t.Fatalf("resume validator = %#v", request.Validator)
		}
		return TransferResult{FinalURL: request.URL, Size: 1024}, nil
	}), store)
	if err != nil {
		t.Fatal(err)
	}
	defer manager.Close()
	restored, err := manager.Get(context.Background(), "segmented")
	if err != nil {
		t.Fatal(err)
	}
	if restored.State != TaskStatePaused || restored.Downloaded != 150 || restored.Downloaded == 1024 {
		t.Fatalf("restored task = %#v", restored)
	}
	if _, err = manager.Resume(context.Background(), restored.ID); err != nil {
		t.Fatal(err)
	}
	waitForTaskState(t, manager, restored.ID, TaskStateCompleted)
	if resumeCalls != 1 {
		t.Fatalf("resume calls = %d", resumeCalls)
	}
	store.mu.Lock()
	persisted := store.records[restored.ID]
	store.mu.Unlock()
	if persisted.Checkpoint != nil {
		t.Fatalf("completed checkpoint was not cleared: %#v", persisted.Checkpoint)
	}
}

func TestRemoteResourceChangeIsNotRetried(t *testing.T) {
	manager := NewManager(context.Background(), transferFunc(func(
		context.Context,
		TransferRequest,
		func(TransferProgress),
	) (TransferResult, error) {
		return TransferResult{}, ErrRemoteChanged
	}), WithRetryPolicy(3, time.Millisecond))
	defer manager.Close()

	task, err := manager.Create(context.Background(), CreateTaskRequest{
		URL: "https://example.com/changing.bin", FileName: "changing.bin", SaveDirectory: t.TempDir(),
		ETag: `"release-v1"`,
	})
	if err != nil {
		t.Fatal(err)
	}
	failed := waitForTaskState(t, manager, task.ID, TaskStateFailed)
	if failed.RetryCount != 0 || failed.Error == nil || failed.Error.Code != "remote_resource_changed" || failed.Error.Retryable {
		t.Fatalf("failed task = %#v", failed)
	}
}

func TestPersistentManagerDiscardsUncheckpointedPreallocatedSegmentFile(t *testing.T) {
	directory := t.TempDir()
	filePath := filepath.Join(directory, "uncheckpointed.bin")
	workPath := temporaryPath(filePath)
	if err := os.WriteFile(workPath, nil, 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Truncate(workPath, DefaultSegmentedTransferMinSize); err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC()
	store := newMemoryTaskStore()
	store.records["uncheckpointed"] = StoredTask{
		Task: Task{
			ID: "uncheckpointed", URL: "https://example.com/uncheckpointed.bin", FinalURL: "https://example.com/uncheckpointed.bin",
			FileName: "uncheckpointed.bin", SaveDirectory: directory, FilePath: filePath,
			State: TaskStateDownloading, Downloaded: 0, Total: DefaultSegmentedTransferMinSize,
			CreatedAt: now, UpdatedAt: now,
		},
		AcceptRanges: true,
	}
	resumeCalls := 0
	manager, err := NewPersistentManager(context.Background(), transferFunc(func(
		_ context.Context,
		request TransferRequest,
		_ func(TransferProgress),
	) (TransferResult, error) {
		resumeCalls++
		if request.Offset != 0 || request.Checkpoint != nil || request.AllowSegments {
			t.Fatalf("safe single-connection restart = %#v", request)
		}
		return TransferResult{FinalURL: request.URL, Size: request.ExpectedSize}, nil
	}), store)
	if err != nil {
		t.Fatal(err)
	}
	defer manager.Close()
	restored, err := manager.Get(context.Background(), "uncheckpointed")
	if err != nil {
		t.Fatal(err)
	}
	if restored.State != TaskStatePaused || restored.Downloaded != 0 {
		t.Fatalf("restored task = %#v", restored)
	}
	if _, err = os.Stat(workPath); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("unverified preallocated file was retained: %v", err)
	}
	if _, err = manager.Resume(context.Background(), restored.ID); err != nil {
		t.Fatal(err)
	}
	waitForTaskState(t, manager, restored.ID, TaskStateCompleted)
	if resumeCalls != 1 {
		t.Fatalf("resume calls = %d", resumeCalls)
	}
}

func TestManagerLimitsConcurrencyAndPreservesFIFOQueueOrder(t *testing.T) {
	directory := t.TempDir()
	started := make(chan string, 3)
	releases := map[string]chan struct{}{
		"one.bin":   make(chan struct{}),
		"two.bin":   make(chan struct{}),
		"three.bin": make(chan struct{}),
	}
	manager := NewManager(context.Background(), transferFunc(func(
		ctx context.Context,
		request TransferRequest,
		_ func(TransferProgress),
	) (TransferResult, error) {
		name := filepath.Base(request.Destination)
		started <- name
		select {
		case <-releases[name]:
			return TransferResult{FinalURL: request.URL, Size: 1}, nil
		case <-ctx.Done():
			return TransferResult{}, ctx.Err()
		}
	}), WithMaxConcurrentTasks(1), WithRetryPolicy(0, time.Millisecond))
	defer manager.Close()

	tasks := make([]Task, 0, 3)
	for _, name := range []string{"one.bin", "two.bin", "three.bin"} {
		task, err := manager.Create(context.Background(), CreateTaskRequest{
			URL: "https://example.com/" + name, FileName: name, SaveDirectory: directory,
		})
		if err != nil {
			t.Fatal(err)
		}
		tasks = append(tasks, task)
	}
	if first := <-started; first != "one.bin" {
		t.Fatalf("first task = %q", first)
	}
	if tasks[0].State != TaskStateDownloading || tasks[1].State != TaskStateQueued || tasks[2].State != TaskStateQueued {
		t.Fatalf("created task states = %q, %q, %q", tasks[0].State, tasks[1].State, tasks[2].State)
	}
	if _, err := manager.Create(context.Background(), CreateTaskRequest{
		URL: "https://mirror.example.com/two.bin", FileName: "two.bin", SaveDirectory: directory,
	}); !errors.Is(err, ErrDestinationExists) {
		t.Fatalf("duplicate queued destination error = %v, want ErrDestinationExists", err)
	}
	paused, err := manager.Pause(context.Background(), tasks[2].ID)
	if err != nil || paused.State != TaskStatePaused {
		t.Fatalf("pause queued task = %#v, error = %v", paused, err)
	}
	select {
	case unexpected := <-started:
		t.Fatalf("queued task started before a slot was free: %q", unexpected)
	case <-time.After(20 * time.Millisecond):
	}

	close(releases["one.bin"])
	if second := <-started; second != "two.bin" {
		t.Fatalf("second task = %q", second)
	}
	resumed, err := manager.Resume(context.Background(), tasks[2].ID)
	if err != nil || resumed.State != TaskStateQueued {
		t.Fatalf("resume queued task = %#v, error = %v", resumed, err)
	}
	close(releases["two.bin"])
	if third := <-started; third != "three.bin" {
		t.Fatalf("third task = %q", third)
	}
	close(releases["three.bin"])
	for _, task := range tasks {
		waitForTaskState(t, manager, task.ID, TaskStateCompleted)
	}
}

func TestManagerRetryBackoffReleasesSlotAndRejoinsQueue(t *testing.T) {
	directory := t.TempDir()
	started := make(chan string, 4)
	releaseSecondTask := make(chan struct{})
	var firstAttemptAt time.Time
	var retryAttemptAt time.Time
	firstAttempts := 0
	manager := NewManager(context.Background(), transferFunc(func(
		ctx context.Context,
		request TransferRequest,
		_ func(TransferProgress),
	) (TransferResult, error) {
		name := filepath.Base(request.Destination)
		if name == "retry.bin" {
			firstAttempts++
			if firstAttempts == 1 {
				firstAttemptAt = time.Now()
				started <- "retry-1"
				return TransferResult{}, ErrRemoteTemporary
			}
			retryAttemptAt = time.Now()
			started <- "retry-2"
			return TransferResult{FinalURL: request.URL, Size: 1}, nil
		}
		started <- "other"
		select {
		case <-releaseSecondTask:
			return TransferResult{FinalURL: request.URL, Size: 1}, nil
		case <-ctx.Done():
			return TransferResult{}, ctx.Err()
		}
	}), WithMaxConcurrentTasks(1), WithRetryPolicy(1, 60*time.Millisecond))
	defer manager.Close()

	retryTask, err := manager.Create(context.Background(), CreateTaskRequest{
		URL: "https://example.com/retry.bin", FileName: "retry.bin", SaveDirectory: directory,
	})
	if err != nil {
		t.Fatal(err)
	}
	if value := <-started; value != "retry-1" {
		t.Fatalf("first start = %q", value)
	}
	retrying := waitForTaskState(t, manager, retryTask.ID, TaskStateRetrying)
	if retrying.RetryCount != 1 || retrying.NextRetryAt == nil || retrying.Error == nil || !retrying.Error.Retryable {
		t.Fatalf("retrying task = %#v", retrying)
	}
	otherTask, err := manager.Create(context.Background(), CreateTaskRequest{
		URL: "https://example.com/other.bin", FileName: "other.bin", SaveDirectory: directory,
	})
	if err != nil {
		t.Fatal(err)
	}
	if value := <-started; value != "other" {
		t.Fatalf("slot was not released during backoff; start = %q", value)
	}
	waitForTaskState(t, manager, retryTask.ID, TaskStateQueued)
	close(releaseSecondTask)
	waitForTaskState(t, manager, otherTask.ID, TaskStateCompleted)
	if value := <-started; value != "retry-2" {
		t.Fatalf("retry did not rejoin queue; start = %q", value)
	}
	completed := waitForTaskState(t, manager, retryTask.ID, TaskStateCompleted)
	if completed.RetryCount != 1 || completed.NextRetryAt != nil || firstAttempts != 2 {
		t.Fatalf("completed retry task = %#v, attempts = %d", completed, firstAttempts)
	}
	if retryAttemptAt.Sub(firstAttemptAt) < 50*time.Millisecond {
		t.Fatalf("retry delay = %s, want exponential backoff", retryAttemptAt.Sub(firstAttemptAt))
	}
}

func TestManagerRestartsRetryFromZeroWithoutValidator(t *testing.T) {
	directory := t.TempDir()
	attempts := 0
	manager := NewManager(context.Background(), transferFunc(func(
		_ context.Context,
		request TransferRequest,
		onProgress func(TransferProgress),
	) (TransferResult, error) {
		attempts++
		if attempts == 1 {
			if err := os.WriteFile(request.WorkPath, []byte("part"), 0o644); err != nil {
				return TransferResult{}, err
			}
			onProgress(TransferProgress{Downloaded: 4, Total: 8})
			return TransferResult{}, ErrRemoteTemporary
		}
		if request.Offset != 0 {
			t.Fatalf("retry offset = %d, want 0", request.Offset)
		}
		if _, err := os.Stat(request.WorkPath); !errors.Is(err, os.ErrNotExist) {
			t.Fatalf("unsafe partial file retained before retry: %v", err)
		}
		return TransferResult{FinalURL: request.URL, Size: 8}, nil
	}), WithRetryPolicy(1, time.Millisecond))
	defer manager.Close()

	task, err := manager.Create(context.Background(), CreateTaskRequest{
		URL: "https://example.com/retry.bin", FileName: "retry.bin", SaveDirectory: directory,
	})
	if err != nil {
		t.Fatal(err)
	}
	completed := waitForTaskState(t, manager, task.ID, TaskStateCompleted)
	if attempts != 2 || completed.Downloaded != 8 || completed.RetryCount != 1 {
		t.Fatalf("completed task = %#v, attempts = %d", completed, attempts)
	}
}

func TestManagerStopsAfterConfiguredRetryBudget(t *testing.T) {
	attempts := 0
	manager := NewManager(context.Background(), transferFunc(func(
		context.Context,
		TransferRequest,
		func(TransferProgress),
	) (TransferResult, error) {
		attempts++
		return TransferResult{}, ErrRemoteTemporary
	}), WithRetryPolicy(2, 5*time.Millisecond))
	defer manager.Close()
	task, err := manager.Create(context.Background(), CreateTaskRequest{
		URL: "https://example.com/fail.bin", FileName: "fail.bin", SaveDirectory: t.TempDir(),
	})
	if err != nil {
		t.Fatal(err)
	}
	failed := waitForTaskState(t, manager, task.ID, TaskStateFailed)
	if attempts != 3 || failed.RetryCount != 2 || failed.NextRetryAt != nil || failed.Error == nil || !failed.Error.Retryable {
		t.Fatalf("failed task = %#v, attempts = %d", failed, attempts)
	}
}

func TestPersistentManagerRestoresQueuedAndRetryingTasksAsPaused(t *testing.T) {
	directory := t.TempDir()
	now := time.Now().UTC()
	retryAt := now.Add(time.Minute)
	store := newMemoryTaskStore()
	for _, state := range []TaskState{TaskStateQueued, TaskStateRetrying} {
		id := string(state)
		store.records[id] = StoredTask{Task: Task{
			ID: id, URL: "https://example.com/" + id + ".bin", FinalURL: "https://example.com/" + id + ".bin",
			FileName: id + ".bin", SaveDirectory: directory, FilePath: filepath.Join(directory, id+".bin"),
			State: state, Total: -1, RetryCount: 1, NextRetryAt: &retryAt, CreatedAt: now, UpdatedAt: now,
		}}
	}
	manager, err := NewPersistentManager(context.Background(), transferFunc(func(
		context.Context, TransferRequest, func(TransferProgress),
	) (TransferResult, error) {
		return TransferResult{}, errors.New("unexpected transfer")
	}), store)
	if err != nil {
		t.Fatal(err)
	}
	defer manager.Close()
	for _, id := range []string{"queued", "retrying"} {
		task, getErr := manager.Get(context.Background(), id)
		if getErr != nil {
			t.Fatal(getErr)
		}
		if task.State != TaskStatePaused || task.NextRetryAt != nil || task.RetryCount != 1 {
			t.Fatalf("restored %s task = %#v", id, task)
		}
	}
}

func waitForTaskState(t *testing.T, manager *Manager, id string, state TaskState) Task {
	t.Helper()
	deadline := time.Now().Add(time.Second)
	for time.Now().Before(deadline) {
		task, err := manager.Get(context.Background(), id)
		if err != nil {
			t.Fatal(err)
		}
		if task.State == state {
			return task
		}
		time.Sleep(time.Millisecond)
	}
	t.Fatalf("task %q did not reach state %q", id, state)
	return Task{}
}

type transferFunc func(context.Context, TransferRequest, func(TransferProgress)) (TransferResult, error)

func (function transferFunc) Download(
	ctx context.Context,
	request TransferRequest,
	onProgress func(TransferProgress),
) (TransferResult, error) {
	return function(ctx, request, onProgress)
}

type memoryTaskStore struct {
	mu      sync.Mutex
	records map[string]StoredTask
}

func newMemoryTaskStore() *memoryTaskStore {
	return &memoryTaskStore{records: make(map[string]StoredTask)}
}

func (store *memoryTaskStore) Load(context.Context) ([]StoredTask, error) {
	store.mu.Lock()
	defer store.mu.Unlock()
	records := make([]StoredTask, 0, len(store.records))
	for _, record := range store.records {
		record.Task = cloneTask(record.Task)
		record.Headers = cloneHeaders(record.Headers)
		record.Checkpoint = CloneTransferCheckpoint(record.Checkpoint)
		records = append(records, record)
	}
	return records, nil
}

func (store *memoryTaskStore) Save(_ context.Context, record StoredTask) error {
	store.mu.Lock()
	defer store.mu.Unlock()
	record.Task = cloneTask(record.Task)
	record.Headers = cloneHeaders(record.Headers)
	record.Checkpoint = CloneTransferCheckpoint(record.Checkpoint)
	store.records[record.Task.ID] = record
	return nil
}

func (*memoryTaskStore) Close() error { return nil }
