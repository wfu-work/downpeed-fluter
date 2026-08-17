package download

import (
	"bytes"
	"context"
	"errors"
	"os"
	"path/filepath"
	"sync"
	"sync/atomic"
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

func TestManagerCreatesPausesResumesAndCompletesBTTask(t *testing.T) {
	directory := t.TempDir()
	started := make(chan struct{}, 2)
	release := make(chan struct{})
	transfer := &stubBTTransfer{
		prepare: func(_ context.Context, input CreateBTTaskRequest) (BTTransferRequest, error) {
			return BTTransferRequest{
				Metadata: []byte("metadata"), SaveDirectory: input.SaveDirectory,
				Name: "archive", Identity: "0123456789abcdef", Total: 8,
				SelectedFileIndexes: []int{0}, ExplicitPeers: []string{"8.8.8.8:6881"},
				Files: []BTFile{{Index: 0, Path: "archive/file.bin", Size: 8}},
			}, nil
		},
		download: func(ctx context.Context, request BTTransferRequest, onProgress func(BTTransferProgress)) (BTTransferResult, error) {
			started <- struct{}{}
			onProgress(BTTransferProgress{
				Downloaded: 4, Total: 8, SpeedBPS: 2, Connections: 1,
				Diagnostics: BTDiagnostics{
					Live:        true,
					Connections: BTConnectionDiagnostics{Known: 2, Connected: 1, Pending: 1},
					Traffic:     BTTrafficDiagnostics{UsefulBytes: 4},
					Peers:       []BTPeerDiagnostics{{Address: "8.8.x.x:6881", Client: "test-peer", Network: "TCP", ReceivedBytes: 4}},
					Policy: BTPolicyDiagnostics{
						MaxPeerConnections: DefaultBTPeerConnections,
						ExplicitPeersOnly:  true,
					},
					UpdatedAt: time.Now().UTC(),
				},
			})
			select {
			case <-release:
				return BTTransferResult{Size: 8}, nil
			case <-ctx.Done():
				return BTTransferResult{}, ctx.Err()
			}
		},
	}
	manager := NewManager(context.Background(), nil, WithBTTransfer(transfer))
	defer manager.Close()
	task, err := manager.CreateBT(context.Background(), CreateBTTaskRequest{
		Metadata: []byte("metadata"), SaveDirectory: directory,
		SelectedFileIndexes: []int{0}, ExplicitPeers: []string{"8.8.8.8:6881"},
	})
	if err != nil {
		t.Fatal(err)
	}
	<-started
	downloading := waitForTaskState(t, manager, task.ID, TaskStateDownloading)
	if downloading.Protocol != ProtocolBT || downloading.Downloaded != 4 || downloading.Connections != 1 {
		t.Fatalf("BT task = %#v", downloading)
	}
	diagnostics, err := manager.GetBTDiagnostics(context.Background(), task.ID)
	if err != nil || !diagnostics.Live || diagnostics.Connections.Configured != 1 || diagnostics.Connections.Known != 2 || len(diagnostics.Peers) != 1 || diagnostics.Peers[0].Address != "8.8.x.x:6881" || diagnostics.Traffic.UsefulBytes != 4 {
		t.Fatalf("BT diagnostics = %#v, error = %v", diagnostics, err)
	}
	paused, err := manager.Pause(context.Background(), task.ID)
	if err != nil || paused.State != TaskStatePaused || paused.Connections != 0 {
		t.Fatalf("Pause() task = %#v, error = %v", paused, err)
	}
	diagnostics, err = manager.GetBTDiagnostics(context.Background(), task.ID)
	if err != nil || diagnostics.Live || diagnostics.Connections.Connected != 0 || len(diagnostics.Peers) != 0 {
		t.Fatalf("paused BT diagnostics = %#v, error = %v", diagnostics, err)
	}
	resumed, err := manager.Resume(context.Background(), task.ID)
	if err != nil || (resumed.State != TaskStateQueued && resumed.State != TaskStateDownloading) {
		t.Fatalf("Resume() task = %#v, error = %v", resumed, err)
	}
	<-started
	close(release)
	completed := waitForTaskState(t, manager, task.ID, TaskStateCompleted)
	if completed.Downloaded != 8 || completed.Total != 8 {
		t.Fatalf("completed BT task = %#v", completed)
	}
}

func TestManagerRejectsUnsafeBTPolicyFromTransferAdapter(t *testing.T) {
	unsafe := DefaultBTPolicySettings()
	unsafe.TrackersEnabled = true
	transfer := &stubBTTransfer{prepare: func(_ context.Context, input CreateBTTaskRequest) (BTTransferRequest, error) {
		return BTTransferRequest{
			Metadata: []byte("metadata"), SaveDirectory: input.SaveDirectory,
			Name: "archive", Identity: "0123456789abcdef", Total: 8,
			SelectedFileIndexes: []int{0}, ExplicitPeers: []string{"8.8.8.8:6881"},
			Files: []BTFile{{Index: 0, Path: "archive/file.bin", Size: 8}}, Policy: unsafe,
		}, nil
	}}
	manager := NewManager(context.Background(), nil, WithBTTransfer(transfer))
	defer manager.Close()
	_, err := manager.CreateBT(context.Background(), CreateBTTaskRequest{
		Metadata: []byte("metadata"), SaveDirectory: t.TempDir(),
		SelectedFileIndexes: []int{0}, ExplicitPeers: []string{"8.8.8.8:6881"},
	})
	if !errors.Is(err, ErrInvalidBTPolicy) {
		t.Fatalf("error = %v, want ErrInvalidBTPolicy", err)
	}
}

func TestPersistentManagerRestoresBTTaskPausedAndResumes(t *testing.T) {
	directory := t.TempDir()
	store := newMemoryTaskStore()
	started := make(chan struct{}, 2)
	firstTransfer := &stubBTTransfer{
		prepare: func(_ context.Context, input CreateBTTaskRequest) (BTTransferRequest, error) {
			return BTTransferRequest{
				Metadata: []byte("metadata"), SaveDirectory: input.SaveDirectory,
				Name: "archive", Identity: "0123456789abcdef", Total: 8,
				SelectedFileIndexes: []int{0}, ExplicitPeers: []string{"8.8.8.8:6881"},
				Files: []BTFile{{Index: 0, Path: "archive/file.bin", Size: 8}},
			}, nil
		},
		download: func(ctx context.Context, _ BTTransferRequest, onProgress func(BTTransferProgress)) (BTTransferResult, error) {
			started <- struct{}{}
			onProgress(BTTransferProgress{Downloaded: 4, Total: 8, Connections: 1})
			<-ctx.Done()
			return BTTransferResult{}, ctx.Err()
		},
	}
	manager, err := NewPersistentManager(context.Background(), nil, store, WithBTTransfer(firstTransfer))
	if err != nil {
		t.Fatal(err)
	}
	task, err := manager.CreateBT(context.Background(), CreateBTTaskRequest{
		Metadata: []byte("metadata"), SaveDirectory: directory,
		SelectedFileIndexes: []int{0}, ExplicitPeers: []string{"8.8.8.8:6881"},
	})
	if err != nil {
		t.Fatal(err)
	}
	<-started
	if err = manager.Close(); err != nil {
		t.Fatal(err)
	}

	resumeCalls := 0
	secondTransfer := &stubBTTransfer{
		prepare: firstTransfer.prepare,
		download: func(_ context.Context, request BTTransferRequest, onProgress func(BTTransferProgress)) (BTTransferResult, error) {
			resumeCalls++
			if string(request.Metadata) != "metadata" || len(request.SelectedFileIndexes) != 1 || request.ExplicitPeers[0] != "8.8.8.8:6881" || request.Policy != DefaultBTPolicySettings() {
				t.Fatalf("restored BT request = %#v", request)
			}
			onProgress(BTTransferProgress{Downloaded: 8, Total: 8, Connections: 1})
			return BTTransferResult{Size: 8}, nil
		},
	}
	restoredManager, err := NewPersistentManager(context.Background(), nil, store, WithBTTransfer(secondTransfer))
	if err != nil {
		t.Fatal(err)
	}
	defer restoredManager.Close()
	restored, err := restoredManager.Get(context.Background(), task.ID)
	if err != nil {
		t.Fatal(err)
	}
	if restored.State != TaskStatePaused || restored.Downloaded != 4 || restored.Connections != 0 || resumeCalls != 0 {
		t.Fatalf("restored BT task = %#v, resume calls = %d", restored, resumeCalls)
	}
	if _, err = restoredManager.Resume(context.Background(), task.ID); err != nil {
		t.Fatal(err)
	}
	completed := waitForTaskState(t, restoredManager, task.ID, TaskStateCompleted)
	if completed.Downloaded != 8 || completed.Total != 8 || resumeCalls != 1 {
		t.Fatalf("completed BT task = %#v, resume calls = %d", completed, resumeCalls)
	}
}

func TestManagerCancelBTCallsCleanup(t *testing.T) {
	directory := t.TempDir()
	started := make(chan struct{})
	cleaned := make(chan BTTransferRequest, 1)
	transfer := &stubBTTransfer{
		prepare: func(_ context.Context, input CreateBTTaskRequest) (BTTransferRequest, error) {
			return BTTransferRequest{
				Metadata: []byte("metadata"), SaveDirectory: input.SaveDirectory,
				Name: "archive", Identity: "0123456789abcdef", Total: 8,
				SelectedFileIndexes: []int{0}, ExplicitPeers: []string{"8.8.8.8:6881"},
				Files: []BTFile{{Index: 0, Path: "archive/file.bin", Size: 8}},
			}, nil
		},
		download: func(ctx context.Context, _ BTTransferRequest, onProgress func(BTTransferProgress)) (BTTransferResult, error) {
			onProgress(BTTransferProgress{Downloaded: 2, Total: 8, Connections: 1})
			close(started)
			<-ctx.Done()
			return BTTransferResult{}, ctx.Err()
		},
		cleanup: func(_ context.Context, request BTTransferRequest) error {
			cleaned <- request
			return nil
		},
	}
	manager := NewManager(context.Background(), nil, WithBTTransfer(transfer))
	defer manager.Close()
	task, err := manager.CreateBT(context.Background(), CreateBTTaskRequest{
		Metadata: []byte("metadata"), SaveDirectory: directory,
		SelectedFileIndexes: []int{0}, ExplicitPeers: []string{"8.8.8.8:6881"},
	})
	if err != nil {
		t.Fatal(err)
	}
	<-started
	canceled, err := manager.Cancel(context.Background(), task.ID)
	if err != nil {
		t.Fatal(err)
	}
	if canceled.State != TaskStateCanceled || canceled.Connections != 0 {
		t.Fatalf("canceled BT task = %#v", canceled)
	}
	select {
	case request := <-cleaned:
		if request.Identity != "0123456789abcdef" {
			t.Fatalf("cleanup request = %#v", request)
		}
	case <-time.After(time.Second):
		t.Fatal("BT cleanup was not called")
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

func TestManagerUniquifiesExistingDestinationAndTemporaryFile(t *testing.T) {
	directory := t.TempDir()
	originalPath := filepath.Join(directory, "keep.bin")
	if err := os.WriteFile(originalPath, []byte("keep"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(temporaryPath(filepath.Join(directory, "keep (1).bin")), []byte("partial"), 0o644); err != nil {
		t.Fatal(err)
	}
	requests := make(chan TransferRequest, 1)
	manager := NewManager(context.Background(), transferFunc(func(
		_ context.Context,
		request TransferRequest,
		_ func(TransferProgress),
	) (TransferResult, error) {
		requests <- request
		return TransferResult{FinalURL: request.URL, Size: 1}, nil
	}), WithFileConflictPolicy(FileConflictPolicyUniquify))
	defer manager.Close()

	task, err := manager.Create(context.Background(), CreateTaskRequest{
		URL: "https://example.com/keep.bin", FileName: "keep.bin", SaveDirectory: directory,
	})
	if err != nil {
		t.Fatal(err)
	}
	request := <-requests
	wantPath := filepath.Join(directory, "keep (2).bin")
	if task.FileName != "keep (2).bin" || task.FilePath != wantPath || request.Destination != wantPath || request.WorkPath != temporaryPath(wantPath) {
		t.Fatalf("task = %#v, request = %#v", task, request)
	}
	contents, err := os.ReadFile(originalPath)
	if err != nil || string(contents) != "keep" {
		t.Fatalf("original file changed: contents=%q error=%v", contents, err)
	}
}

func TestManagerUniquifiesDestinationUsedByActiveTask(t *testing.T) {
	directory := t.TempDir()
	started := make(chan string, 1)
	release := make(chan struct{})
	manager := NewManager(context.Background(), transferFunc(func(
		ctx context.Context,
		request TransferRequest,
		_ func(TransferProgress),
	) (TransferResult, error) {
		started <- filepath.Base(request.Destination)
		select {
		case <-release:
			return TransferResult{FinalURL: request.URL, Size: 1}, nil
		case <-ctx.Done():
			return TransferResult{}, ctx.Err()
		}
	}), WithMaxConcurrentTasks(1), WithFileConflictPolicy(FileConflictPolicyUniquify))
	defer manager.Close()
	defer close(release)

	if _, err := manager.Create(context.Background(), CreateTaskRequest{
		URL: "https://example.com/report.zip", FileName: "report.zip", SaveDirectory: directory,
	}); err != nil {
		t.Fatal(err)
	}
	if name := <-started; name != "report.zip" {
		t.Fatalf("started task = %q", name)
	}
	second, err := manager.Create(context.Background(), CreateTaskRequest{
		URL: "https://mirror.example.com/report.zip", FileName: "report.zip", SaveDirectory: directory,
	})
	if err != nil {
		t.Fatal(err)
	}
	if second.FileName != "report (1).zip" || second.State != TaskStateQueued {
		t.Fatalf("second task = %#v", second)
	}
}

func TestManagerKeepsBTConflictHandlingStrictWhenHTTPUniquifyIsEnabled(t *testing.T) {
	directory := t.TempDir()
	if err := os.Mkdir(filepath.Join(directory, "archive"), 0o755); err != nil {
		t.Fatal(err)
	}
	transfer := &stubBTTransfer{prepare: func(_ context.Context, input CreateBTTaskRequest) (BTTransferRequest, error) {
		return BTTransferRequest{
			Metadata: []byte("metadata"), SaveDirectory: input.SaveDirectory,
			Name: "archive", Identity: "0123456789abcdef", Total: 8,
			SelectedFileIndexes: []int{0}, ExplicitPeers: []string{"8.8.8.8:6881"},
			Files: []BTFile{{Index: 0, Path: "archive/file.bin", Size: 8}},
		}, nil
	}}
	manager := NewManager(
		context.Background(), nil,
		WithBTTransfer(transfer),
		WithFileConflictPolicy(FileConflictPolicyUniquify),
	)
	defer manager.Close()
	_, err := manager.CreateBT(context.Background(), CreateBTTaskRequest{
		Metadata: []byte("metadata"), SaveDirectory: directory,
		SelectedFileIndexes: []int{0}, ExplicitPeers: []string{"8.8.8.8:6881"},
	})
	if !errors.Is(err, ErrDestinationExists) {
		t.Fatalf("CreateBT() error = %v, want ErrDestinationExists", err)
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

func TestManagerAppliesSchedulerSettingsWithoutInterruptingRunningTasks(t *testing.T) {
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
	}), WithMaxConcurrentTasks(1), WithRetryPolicy(2, time.Millisecond))
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
	manager.ApplySchedulerSettings(SchedulerSettings{
		MaxConcurrentTasks: 2,
		DownloadRateLimit:  0,
		MaxRetries:         2,
	})
	if second := <-started; second != "two.bin" {
		t.Fatalf("second task after expanding slots = %q", second)
	}
	manager.ApplySchedulerSettings(SchedulerSettings{
		MaxConcurrentTasks: 1,
		DownloadRateLimit:  0,
		MaxRetries:         2,
	})
	close(releases["one.bin"])
	select {
	case unexpected := <-started:
		t.Fatalf("queued task started while one existing run still occupied the reduced limit: %q", unexpected)
	case <-time.After(30 * time.Millisecond):
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

func TestManagerAppliesUpdatedRetryBudget(t *testing.T) {
	started := make(chan struct{})
	release := make(chan struct{})
	manager := NewManager(context.Background(), transferFunc(func(
		context.Context,
		TransferRequest,
		func(TransferProgress),
	) (TransferResult, error) {
		close(started)
		<-release
		return TransferResult{}, ErrRemoteTemporary
	}), WithRetryPolicy(2, time.Millisecond))
	defer manager.Close()
	task, err := manager.Create(context.Background(), CreateTaskRequest{
		URL: "https://example.com/retry.bin", FileName: "retry.bin", SaveDirectory: t.TempDir(),
	})
	if err != nil {
		t.Fatal(err)
	}
	<-started
	manager.ApplySchedulerSettings(SchedulerSettings{
		MaxConcurrentTasks: DefaultMaxConcurrentTasks,
		MaxRetries:         0,
	})
	close(release)
	failed := waitForTaskState(t, manager, task.ID, TaskStateFailed)
	if failed.RetryCount != 0 || failed.NextRetryAt != nil {
		t.Fatalf("task retried after the runtime budget was disabled: %#v", failed)
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

func TestManagerRetriesFailedTaskOnDemand(t *testing.T) {
	var attempts atomic.Int32
	manager := NewManager(context.Background(), transferFunc(func(
		context.Context,
		TransferRequest,
		func(TransferProgress),
	) (TransferResult, error) {
		if attempts.Add(1) == 1 {
			return TransferResult{}, ErrRemoteTemporary
		}
		return TransferResult{FinalURL: "https://cdn.example.com/retry.bin", Size: 8}, nil
	}), WithRetryPolicy(0, time.Millisecond))
	defer manager.Close()
	task, err := manager.Create(context.Background(), CreateTaskRequest{
		URL: "https://example.com/retry.bin", FileName: "retry.bin", SaveDirectory: t.TempDir(),
	})
	if err != nil {
		t.Fatal(err)
	}
	failed := waitForTaskState(t, manager, task.ID, TaskStateFailed)
	if failed.Error == nil || !failed.Error.Retryable {
		t.Fatalf("failed task = %#v", failed)
	}

	retrying, err := manager.Retry(context.Background(), task.ID)
	if err != nil {
		t.Fatalf("Retry() error = %v", err)
	}
	if retrying.Error != nil || retrying.CompletedAt != nil || retrying.RetryCount != 0 ||
		(retrying.State != TaskStateQueued && retrying.State != TaskStateDownloading) {
		t.Fatalf("retrying task = %#v", retrying)
	}
	completed := waitForTaskState(t, manager, task.ID, TaskStateCompleted)
	if attempts.Load() != 2 || completed.Downloaded != 8 || completed.Error != nil {
		t.Fatalf("completed task = %#v, attempts = %d", completed, attempts.Load())
	}
}

func TestManagerRejectsUnsafeFailedTaskRetry(t *testing.T) {
	manager := NewManager(context.Background(), transferFunc(func(
		context.Context,
		TransferRequest,
		func(TransferProgress),
	) (TransferResult, error) {
		return TransferResult{}, ErrRemoteChanged
	}), WithRetryPolicy(0, time.Millisecond))
	defer manager.Close()
	task, err := manager.Create(context.Background(), CreateTaskRequest{
		URL: "https://example.com/changed.bin", FileName: "changed.bin", SaveDirectory: t.TempDir(),
	})
	if err != nil {
		t.Fatal(err)
	}
	failed := waitForTaskState(t, manager, task.ID, TaskStateFailed)
	if failed.Error == nil || failed.Error.Retryable {
		t.Fatalf("failed task = %#v", failed)
	}
	if _, err = manager.Retry(context.Background(), task.ID); !errors.Is(err, ErrTaskRetryNotAllowed) {
		t.Fatalf("Retry() error = %v", err)
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

func TestManagerDeletesTerminalTaskRecordAndPublishesRemoval(t *testing.T) {
	directory := t.TempDir()
	filePath := filepath.Join(directory, "completed.bin")
	if err := os.WriteFile(filePath, []byte("downpeed"), 0o644); err != nil {
		t.Fatal(err)
	}
	store := newMemoryTaskStore()
	store.records["completed"] = storedTerminalTask("completed", filePath, TaskStateCompleted)
	manager, err := NewPersistentManager(context.Background(), nil, store)
	if err != nil {
		t.Fatal(err)
	}
	subscriptionContext, cancelSubscription := context.WithCancel(context.Background())
	defer cancelSubscription()
	events := manager.Subscribe(subscriptionContext)

	result, err := manager.Delete(context.Background(), "completed", false)
	if err != nil {
		t.Fatalf("Delete() error = %v", err)
	}
	if result.ID != "completed" || result.FileDeleted {
		t.Fatalf("Delete() result = %#v", result)
	}
	if _, err = os.Stat(filePath); err != nil {
		t.Fatalf("downloaded file was not preserved: %v", err)
	}
	if _, err = manager.Get(context.Background(), "completed"); !errors.Is(err, ErrTaskNotFound) {
		t.Fatalf("Get() after Delete() error = %v, want ErrTaskNotFound", err)
	}
	store.mu.Lock()
	_, persisted := store.records["completed"]
	store.mu.Unlock()
	if persisted {
		t.Fatal("deleted task remains in the task store")
	}
	select {
	case event := <-events:
		if event.Type != TaskRemovedEvent || event.Task.ID != "completed" {
			t.Fatalf("removal event = %#v", event)
		}
	case <-time.After(time.Second):
		t.Fatal("timed out waiting for task.removed event")
	}
	if err = manager.Close(); err != nil {
		t.Fatal(err)
	}
	restored, err := NewPersistentManager(context.Background(), nil, store)
	if err != nil {
		t.Fatal(err)
	}
	defer restored.Close()
	if tasks, listErr := restored.List(context.Background()); listErr != nil || len(tasks) != 0 {
		t.Fatalf("restored tasks = %#v, error = %v", tasks, listErr)
	}
}

func TestManagerOptionallyDeletesCompletedRegularFile(t *testing.T) {
	directory := t.TempDir()
	filePath := filepath.Join(directory, "completed.bin")
	if err := os.WriteFile(filePath, []byte("downpeed"), 0o644); err != nil {
		t.Fatal(err)
	}
	store := newMemoryTaskStore()
	store.records["completed"] = storedTerminalTask("completed", filePath, TaskStateCompleted)
	manager, err := NewPersistentManager(context.Background(), nil, store)
	if err != nil {
		t.Fatal(err)
	}
	defer manager.Close()

	result, err := manager.Delete(context.Background(), "completed", true)
	if err != nil {
		t.Fatalf("Delete() error = %v", err)
	}
	if !result.FileDeleted {
		t.Fatalf("Delete() result = %#v", result)
	}
	if _, err = os.Stat(filePath); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("downloaded file still exists: %v", err)
	}
}

func TestManagerDeletesFailedAndCanceledRecords(t *testing.T) {
	for _, state := range []TaskState{TaskStateFailed, TaskStateCanceled} {
		t.Run(string(state), func(t *testing.T) {
			directory := t.TempDir()
			store := newMemoryTaskStore()
			store.records[string(state)] = storedTerminalTask(
				string(state),
				filepath.Join(directory, string(state)+".bin"),
				state,
			)
			manager, err := NewPersistentManager(context.Background(), nil, store)
			if err != nil {
				t.Fatal(err)
			}
			defer manager.Close()

			if _, err = manager.Delete(context.Background(), string(state), true); err != nil {
				t.Fatalf("Delete() error = %v", err)
			}
			if _, err = manager.Get(context.Background(), string(state)); !errors.Is(err, ErrTaskNotFound) {
				t.Fatalf("Get() error = %v, want ErrTaskNotFound", err)
			}
		})
	}
}

func TestManagerRejectsDeletingNonTerminalTask(t *testing.T) {
	for _, state := range []TaskState{
		TaskStateQueued,
		TaskStateDownloading,
		TaskStateRetrying,
		TaskStatePaused,
	} {
		t.Run(string(state), func(t *testing.T) {
			manager := NewManager(context.Background(), nil)
			defer manager.Close()
			manager.tasks["active"] = Task{ID: "active", State: state}

			if _, err := manager.Delete(context.Background(), "active", false); !errors.Is(err, ErrTaskInvalidState) {
				t.Fatalf("Delete() error = %v, want ErrTaskInvalidState", err)
			}
			if _, err := manager.Get(context.Background(), "active"); err != nil {
				t.Fatalf("task was removed after rejected Delete(): %v", err)
			}
		})
	}
}

func TestManagerRefusesToDeleteNonRegularDestination(t *testing.T) {
	directory := t.TempDir()
	store := newMemoryTaskStore()
	store.records["completed"] = storedTerminalTask("completed", directory, TaskStateCompleted)
	manager, err := NewPersistentManager(context.Background(), nil, store)
	if err != nil {
		t.Fatal(err)
	}
	defer manager.Close()

	if _, err = manager.Delete(context.Background(), "completed", true); !errors.Is(err, ErrTaskFileDelete) {
		t.Fatalf("Delete() error = %v, want ErrTaskFileDelete", err)
	}
	if _, err = manager.Get(context.Background(), "completed"); err != nil {
		t.Fatalf("task record was removed after file safety failure: %v", err)
	}
	if info, err := os.Stat(directory); err != nil || !info.IsDir() {
		t.Fatalf("destination directory changed: info=%#v error=%v", info, err)
	}
}

func storedTerminalTask(id, filePath string, state TaskState) StoredTask {
	now := time.Date(2026, time.August, 11, 1, 0, 0, 0, time.UTC)
	completedAt := now
	return StoredTask{Task: Task{
		ID:            id,
		URL:           "https://example.com/" + filepath.Base(filePath),
		FinalURL:      "https://example.com/" + filepath.Base(filePath),
		FileName:      filepath.Base(filePath),
		SaveDirectory: filepath.Dir(filePath),
		FilePath:      filePath,
		State:         state,
		Total:         -1,
		CreatedAt:     now,
		UpdatedAt:     now,
		CompletedAt:   &completedAt,
	}}
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

type stubBTTransfer struct {
	prepare  func(context.Context, CreateBTTaskRequest) (BTTransferRequest, error)
	download func(context.Context, BTTransferRequest, func(BTTransferProgress)) (BTTransferResult, error)
	cleanup  func(context.Context, BTTransferRequest) error
}

func (stub *stubBTTransfer) Prepare(ctx context.Context, request CreateBTTaskRequest) (BTTransferRequest, error) {
	return stub.prepare(ctx, request)
}

func (stub *stubBTTransfer) Download(ctx context.Context, request BTTransferRequest, progress func(BTTransferProgress)) (BTTransferResult, error) {
	return stub.download(ctx, request, progress)
}

func (stub *stubBTTransfer) Cleanup(ctx context.Context, request BTTransferRequest) error {
	if stub.cleanup == nil {
		return nil
	}
	return stub.cleanup(ctx, request)
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
		record.BT = CloneStoredBTTask(record.BT)
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
	record.BT = CloneStoredBTTask(record.BT)
	store.records[record.Task.ID] = record
	return nil
}

func (store *memoryTaskStore) Delete(_ context.Context, id string) error {
	store.mu.Lock()
	defer store.mu.Unlock()
	delete(store.records, id)
	return nil
}

func (*memoryTaskStore) Close() error { return nil }
