package repository

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/wfu-work/downpeed-fluter/backend/internal/download"
)

func TestBoltTaskStorePersistsAndUpdatesTasks(t *testing.T) {
	path := filepath.Join(t.TempDir(), "data", "tasks.db")
	store, err := OpenBoltTaskStore(path)
	if err != nil {
		t.Fatal(err)
	}
	now := time.Date(2026, time.August, 11, 1, 0, 0, 0, time.UTC)
	record := download.StoredTask{
		Task: download.Task{
			ID:            "task-1",
			URL:           "https://example.com/file.bin",
			FinalURL:      "https://example.com/file.bin",
			FileName:      "file.bin",
			SaveDirectory: filepath.Dir(path),
			FilePath:      filepath.Join(filepath.Dir(path), "file.bin"),
			State:         download.TaskStatePaused,
			Downloaded:    128,
			Total:         1024,
			CreatedAt:     now,
			UpdatedAt:     now,
		},
		Headers:      map[string]string{"Authorization": "secret"},
		AcceptRanges: true,
		Validator: download.ResourceValidator{
			ETag:         `"release-v1"`,
			LastModified: "Tue, 11 Aug 2026 01:02:03 GMT",
		},
		Checkpoint: &download.TransferCheckpoint{
			Version: download.TransferCheckpointVersion,
			Total:   1024,
			Segments: []download.SegmentProgress{
				{Start: 0, End: 511, Completed: 256},
				{Start: 512, End: 1023, Completed: 0},
			},
		},
	}
	if err = store.Save(context.Background(), record); err != nil {
		t.Fatal(err)
	}
	record.Task.Downloaded = 256
	if err = store.Save(context.Background(), record); err != nil {
		t.Fatal(err)
	}
	if err = store.Close(); err != nil {
		t.Fatal(err)
	}
	if err = os.Chmod(path, 0o644); err != nil {
		t.Fatal(err)
	}

	reopened, err := OpenBoltTaskStore(path)
	if err != nil {
		t.Fatal(err)
	}
	defer reopened.Close()
	records, err := reopened.Load(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if len(records) != 1 || records[0].Task.Downloaded != 256 {
		t.Fatalf("records = %#v", records)
	}
	if records[0].Headers["Authorization"] != "secret" {
		t.Fatalf("headers = %#v", records[0].Headers)
	}
	if !records[0].AcceptRanges || records[0].Checkpoint == nil || records[0].Checkpoint.Segments[0].Completed != 256 {
		t.Fatalf("segmented transfer state = %#v", records[0])
	}
	if records[0].Validator.ETag != `"release-v1"` || records[0].Validator.LastModified == "" {
		t.Fatalf("resource validator = %#v", records[0].Validator)
	}
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm()&0o077 != 0 {
		t.Fatalf("database permissions = %o", info.Mode().Perm())
	}
}

func TestBoltTaskStoreRejectsRelativePath(t *testing.T) {
	if _, err := OpenBoltTaskStore("tasks.db"); err == nil {
		t.Fatal("OpenBoltTaskStore() error = nil")
	}
}

func TestBoltTaskStoreDeletesTaskAcrossReopen(t *testing.T) {
	path := filepath.Join(t.TempDir(), "data", "tasks.db")
	store, err := OpenBoltTaskStore(path)
	if err != nil {
		t.Fatal(err)
	}
	record := download.StoredTask{Task: download.Task{
		ID:            "task-delete",
		URL:           "https://example.com/file.bin",
		FinalURL:      "https://example.com/file.bin",
		FileName:      "file.bin",
		SaveDirectory: filepath.Dir(path),
		FilePath:      filepath.Join(filepath.Dir(path), "file.bin"),
		State:         download.TaskStateCompleted,
		Total:         -1,
		CreatedAt:     time.Now().UTC(),
		UpdatedAt:     time.Now().UTC(),
	}}
	if err = store.Save(context.Background(), record); err != nil {
		t.Fatal(err)
	}
	if err = store.Delete(context.Background(), record.Task.ID); err != nil {
		t.Fatal(err)
	}
	if err = store.Close(); err != nil {
		t.Fatal(err)
	}

	reopened, err := OpenBoltTaskStore(path)
	if err != nil {
		t.Fatal(err)
	}
	defer reopened.Close()
	records, err := reopened.Load(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if len(records) != 0 {
		t.Fatalf("records after Delete() = %#v", records)
	}
}

func TestBoltTaskStorePersistsEngineSettingsAcrossReopen(t *testing.T) {
	path := filepath.Join(t.TempDir(), "data", "tasks.db")
	store, err := OpenBoltTaskStore(path)
	if err != nil {
		t.Fatal(err)
	}
	directory := filepath.Join(filepath.Dir(path), "downloads")
	settings := download.EngineSettings{DefaultDownloadDirectory: directory}
	if err = store.SaveSettings(context.Background(), settings); err != nil {
		t.Fatal(err)
	}
	if err = store.Close(); err != nil {
		t.Fatal(err)
	}
	reopened, err := OpenBoltTaskStore(path)
	if err != nil {
		t.Fatal(err)
	}
	defer reopened.Close()
	loaded, err := reopened.LoadSettings(context.Background())
	if err != nil || loaded != settings {
		t.Fatalf("settings = %#v, error = %v", loaded, err)
	}
}
