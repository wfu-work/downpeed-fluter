package diagnostics

import (
	"archive/zip"
	"bytes"
	"context"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/wfu-work/downpeed-fluter/backend/internal/download"
)

func TestSnapshotSummarizesTasksAndRedactsStoragePaths(t *testing.T) {
	root := t.TempDir()
	databasePath := filepath.Join(root, "tasks.db")
	if err := os.WriteFile(databasePath, []byte("database"), 0o600); err != nil {
		t.Fatal(err)
	}
	service := New(Config{
		DataDirectory: root,
		DatabasePath:  databasePath,
		StartedAt:     time.Date(2026, time.August, 17, 1, 0, 0, 0, time.UTC),
	}, taskListerFunc(func(context.Context) ([]download.Task, error) {
		return []download.Task{
			{Protocol: download.ProtocolHTTP, State: download.TaskStateDownloading},
			{Protocol: download.ProtocolBT, State: download.TaskStateRetrying},
			{Protocol: download.ProtocolHTTP, State: download.TaskStateQueued},
			{Protocol: download.ProtocolHTTP, State: download.TaskStateCompleted},
			{Protocol: download.ProtocolBT, State: download.TaskStateFailed},
		}, nil
	}), settingsServiceStub{settings: safeTestSettings(filepath.Join(root, "Downloads"))})
	service.now = func() time.Time {
		return time.Date(2026, time.August, 17, 1, 2, 0, 0, time.UTC)
	}

	snapshot, err := service.Snapshot(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if snapshot.Storage.DataDirectory == root || snapshot.Storage.DatabasePath == databasePath {
		t.Fatalf("storage paths were not redacted: %#v", snapshot.Storage)
	}
	if !strings.HasPrefix(snapshot.Storage.DataDirectory, "$TMPDIR") {
		t.Fatalf("data directory = %q", snapshot.Storage.DataDirectory)
	}
	if !snapshot.Storage.DatabaseAvailable || snapshot.Storage.DatabaseSizeBytes != int64(len("database")) {
		t.Fatalf("database info = %#v", snapshot.Storage)
	}
	if snapshot.Storage.LogsAvailable || snapshot.Storage.LogPath != "" {
		t.Fatalf("log info = %#v", snapshot.Storage)
	}
	if snapshot.Tasks.Total != 5 || snapshot.Tasks.Active != 2 || snapshot.Tasks.Queued != 1 || snapshot.Tasks.Completed != 1 || snapshot.Tasks.Failed != 1 || snapshot.Tasks.HTTP != 3 || snapshot.Tasks.BitTorrent != 2 {
		t.Fatalf("task summary = %#v", snapshot.Tasks)
	}
	if snapshot.Engine.UptimeMS != 120_000 {
		t.Fatalf("uptime = %d", snapshot.Engine.UptimeMS)
	}
	if !snapshot.Privacy.PathsRedacted || snapshot.Privacy.TaskDetailsIncluded || snapshot.Privacy.LogsIncluded {
		t.Fatalf("privacy = %#v", snapshot.Privacy)
	}
}

func TestExportExcludesTaskAndRequestSecrets(t *testing.T) {
	root := t.TempDir()
	databasePath := filepath.Join(root, "tasks.db")
	if err := os.WriteFile(databasePath, []byte("database"), 0o600); err != nil {
		t.Fatal(err)
	}
	const secretURL = "https://user:password@example.com/file?token=private"
	const secretFileName = "customer-contract.pdf"
	const secretIdentifier = "task-private-identifier"
	service := New(Config{
		DataDirectory: root,
		DatabasePath:  databasePath,
		StartedAt:     time.Date(2026, time.August, 17, 1, 0, 0, 0, time.UTC),
	}, taskListerFunc(func(context.Context) ([]download.Task, error) {
		return []download.Task{{
			ID:       secretIdentifier,
			URL:      secretURL,
			FileName: secretFileName,
			Protocol: download.ProtocolHTTP,
			State:    download.TaskStatePaused,
		}}, nil
	}), settingsServiceStub{settings: safeTestSettings(filepath.Join(root, "private-downloads"))})
	service.now = func() time.Time {
		return time.Date(2026, time.August, 17, 1, 2, 3, 0, time.UTC)
	}

	archive, err := service.Export(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if archive.Filename != "downpeed-diagnostics-20260817-010203Z.zip" {
		t.Fatalf("filename = %q", archive.Filename)
	}
	reader, err := zip.NewReader(bytes.NewReader(archive.Bytes), int64(len(archive.Bytes)))
	if err != nil {
		t.Fatal(err)
	}
	contents := strings.Builder{}
	names := make(map[string]bool)
	for _, file := range reader.File {
		names[file.Name] = true
		entry, openErr := file.Open()
		if openErr != nil {
			t.Fatal(openErr)
		}
		value, readErr := io.ReadAll(entry)
		_ = entry.Close()
		if readErr != nil {
			t.Fatal(readErr)
		}
		contents.Write(value)
	}
	for _, name := range []string{"manifest.json", "storage.json", "settings.json", "tasks.json", "README.txt"} {
		if !names[name] {
			t.Fatalf("archive entry %q is missing", name)
		}
	}
	text := contents.String()
	for _, secret := range []string{secretURL, "password", "token=private", secretFileName, secretIdentifier, "internal-proxy.example", "private-user", root} {
		if strings.Contains(text, secret) {
			t.Fatalf("diagnostic archive contains secret %q", secret)
		}
	}
}

func TestRedactPathKeepsOnlyTheBaseOutsideKnownRoots(t *testing.T) {
	volumeRoot := filepath.VolumeName(os.TempDir()) + string(filepath.Separator)
	path := filepath.Join(volumeRoot, "outside", "customer-private", "Downpeed")
	if got, want := redactPath(path), filepath.Join("<redacted>", "Downpeed"); got != want {
		t.Fatalf("redactPath(%q) = %q, want %q", path, got, want)
	}
}

func safeTestSettings(directory string) download.EngineSettings {
	return download.EngineSettings{
		DefaultDownloadDirectory: directory,
		FileConflictPolicy:       download.DefaultFileConflictPolicy,
		Scheduler: download.SchedulerSettings{
			MaxConcurrentTasks: 3,
			DownloadRateLimit:  0,
			MaxRetries:         2,
		},
		Proxy: download.ProxySettings{
			Mode:                         download.ProxyModeHTTP,
			Host:                         "internal-proxy.example",
			Port:                         8080,
			Username:                     "private-user",
			ConnectTimeoutSeconds:        10,
			ResponseHeaderTimeoutSeconds: 30,
		},
		BitTorrent: download.DefaultBTPolicySettings(),
	}
}

type taskListerFunc func(context.Context) ([]download.Task, error)

func (function taskListerFunc) List(ctx context.Context) ([]download.Task, error) {
	return function(ctx)
}

type settingsServiceStub struct {
	settings download.EngineSettings
	err      error
}

func (stub settingsServiceStub) GetSettings(context.Context) (download.EngineSettings, error) {
	return stub.settings, stub.err
}

func (stub settingsServiceStub) UpdateSettings(context.Context, download.EngineSettings) (download.EngineSettings, error) {
	return download.EngineSettings{}, errors.New("unexpected UpdateSettings call")
}
