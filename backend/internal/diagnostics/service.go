package diagnostics

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"

	"github.com/wfu-work/downpeed-fluter/backend/internal/buildinfo"
	"github.com/wfu-work/downpeed-fluter/backend/internal/download"
)

var ErrUnavailable = errors.New("engine diagnostics are unavailable")

type TaskLister interface {
	List(context.Context) ([]download.Task, error)
}

type Provider interface {
	Snapshot(context.Context) (Snapshot, error)
	Export(context.Context) (Archive, error)
}

type Config struct {
	DataDirectory string
	DatabasePath  string
	StartedAt     time.Time
}

type Service struct {
	config   Config
	tasks    TaskLister
	settings download.SettingsService
	now      func() time.Time
}

type Snapshot struct {
	GeneratedAt time.Time       `json:"generatedAt"`
	Engine      EngineInfo      `json:"engine"`
	Storage     StorageInfo     `json:"storage"`
	Settings    SettingsSummary `json:"settings"`
	Tasks       TaskSummary     `json:"tasks"`
	Privacy     PrivacyInfo     `json:"privacy"`
}

type EngineInfo struct {
	Name       string    `json:"name"`
	Version    string    `json:"version"`
	Commit     string    `json:"commit"`
	BuildDate  string    `json:"buildDate"`
	APIVersion string    `json:"apiVersion"`
	GoVersion  string    `json:"goVersion"`
	OS         string    `json:"os"`
	Arch       string    `json:"arch"`
	StartedAt  time.Time `json:"startedAt"`
	UptimeMS   int64     `json:"uptimeMs"`
}

type StorageInfo struct {
	DataDirectory     string `json:"dataDirectory"`
	DatabasePath      string `json:"databasePath"`
	DatabaseSizeBytes int64  `json:"databaseSizeBytes"`
	DatabaseAvailable bool   `json:"databaseAvailable"`
	LogsAvailable     bool   `json:"logsAvailable"`
	LogPath           string `json:"logPath,omitempty"`
}

type SettingsSummary struct {
	DefaultDownloadDirectory string                      `json:"defaultDownloadDirectory"`
	FileConflictPolicy       download.FileConflictPolicy `json:"fileConflictPolicy"`
	Scheduler                download.SchedulerSettings  `json:"scheduler"`
	Proxy                    ProxySettingsSummary        `json:"proxy"`
	BitTorrent               download.BTPolicySettings   `json:"bitTorrent"`
}

type ProxySettingsSummary struct {
	Mode                         download.ProxyMode `json:"mode"`
	ConnectTimeoutSeconds        int                `json:"connectTimeoutSeconds"`
	ResponseHeaderTimeoutSeconds int                `json:"responseHeaderTimeoutSeconds"`
}

type TaskSummary struct {
	Total      int `json:"total"`
	Active     int `json:"active"`
	Queued     int `json:"queued"`
	Paused     int `json:"paused"`
	Completed  int `json:"completed"`
	Failed     int `json:"failed"`
	Canceled   int `json:"canceled"`
	HTTP       int `json:"http"`
	BitTorrent int `json:"bitTorrent"`
}

type PrivacyInfo struct {
	PathsRedacted       bool `json:"pathsRedacted"`
	TaskDetailsIncluded bool `json:"taskDetailsIncluded"`
	LogsIncluded        bool `json:"logsIncluded"`
}

type Archive struct {
	Filename string
	Bytes    []byte
}

func New(config Config, tasks TaskLister, settings download.SettingsService) *Service {
	return &Service{
		config:   config,
		tasks:    tasks,
		settings: settings,
		now:      time.Now,
	}
}

func (s *Service) Snapshot(ctx context.Context) (Snapshot, error) {
	if err := ctx.Err(); err != nil {
		return Snapshot{}, err
	}
	if s.tasks == nil || s.settings == nil {
		return Snapshot{}, ErrUnavailable
	}
	tasks, err := s.tasks.List(ctx)
	if err != nil {
		return Snapshot{}, fmt.Errorf("%w: list tasks", ErrUnavailable)
	}
	settings, err := s.settings.GetSettings(ctx)
	if err != nil {
		return Snapshot{}, fmt.Errorf("%w: read settings", ErrUnavailable)
	}

	now := s.now().UTC()
	startedAt := s.config.StartedAt.UTC()
	if startedAt.IsZero() {
		startedAt = now
	}
	uptime := now.Sub(startedAt)
	if uptime < 0 {
		uptime = 0
	}
	databaseSize, databaseAvailable := databaseInfo(s.config.DatabasePath)

	return Snapshot{
		GeneratedAt: now,
		Engine: EngineInfo{
			Name:       "Downpeed Engine",
			Version:    buildinfo.Version,
			Commit:     buildinfo.Commit,
			BuildDate:  buildinfo.Date,
			APIVersion: buildinfo.APIVersion,
			GoVersion:  runtime.Version(),
			OS:         runtime.GOOS,
			Arch:       runtime.GOARCH,
			StartedAt:  startedAt,
			UptimeMS:   uptime.Milliseconds(),
		},
		Storage: StorageInfo{
			DataDirectory:     redactPath(s.config.DataDirectory),
			DatabasePath:      redactPath(s.config.DatabasePath),
			DatabaseSizeBytes: databaseSize,
			DatabaseAvailable: databaseAvailable,
			LogsAvailable:     false,
		},
		Settings: SettingsSummary{
			DefaultDownloadDirectory: redactPath(settings.DefaultDownloadDirectory),
			FileConflictPolicy:       settings.FileConflictPolicy,
			Scheduler:                settings.Scheduler,
			Proxy: ProxySettingsSummary{
				Mode:                         settings.Proxy.Mode,
				ConnectTimeoutSeconds:        settings.Proxy.ConnectTimeoutSeconds,
				ResponseHeaderTimeoutSeconds: settings.Proxy.ResponseHeaderTimeoutSeconds,
			},
			BitTorrent: settings.BitTorrent,
		},
		Tasks: summarizeTasks(tasks),
		Privacy: PrivacyInfo{
			PathsRedacted:       true,
			TaskDetailsIncluded: false,
			LogsIncluded:        false,
		},
	}, nil
}

func (s *Service) Export(ctx context.Context) (Archive, error) {
	snapshot, err := s.Snapshot(ctx)
	if err != nil {
		return Archive{}, err
	}

	var buffer bytes.Buffer
	writer := zip.NewWriter(&buffer)
	entries := []struct {
		name  string
		value any
	}{
		{"manifest.json", struct {
			GeneratedAt time.Time   `json:"generatedAt"`
			Engine      EngineInfo  `json:"engine"`
			Privacy     PrivacyInfo `json:"privacy"`
		}{snapshot.GeneratedAt, snapshot.Engine, snapshot.Privacy}},
		{"storage.json", snapshot.Storage},
		{"settings.json", snapshot.Settings},
		{"tasks.json", snapshot.Tasks},
	}
	for _, entry := range entries {
		if err = writeJSONEntry(writer, entry.name, entry.value); err != nil {
			_ = writer.Close()
			return Archive{}, fmt.Errorf("%w: build archive", ErrUnavailable)
		}
	}
	readme, err := writer.Create("README.txt")
	if err != nil {
		_ = writer.Close()
		return Archive{}, fmt.Errorf("%w: build archive", ErrUnavailable)
	}
	if _, err = readme.Write([]byte("Downpeed diagnostic bundle\n\nPaths are shortened. Task URLs, headers, cookies, proxy credentials, torrent metadata, file names, and task identifiers are not included. This build does not retain engine logs on disk.\n")); err != nil {
		_ = writer.Close()
		return Archive{}, fmt.Errorf("%w: build archive", ErrUnavailable)
	}
	if err = writer.Close(); err != nil {
		return Archive{}, fmt.Errorf("%w: finalize archive", ErrUnavailable)
	}

	return Archive{
		Filename: "downpeed-diagnostics-" + snapshot.GeneratedAt.Format("20060102-150405Z") + ".zip",
		Bytes:    buffer.Bytes(),
	}, nil
}

func writeJSONEntry(writer *zip.Writer, name string, value any) error {
	entry, err := writer.Create(name)
	if err != nil {
		return err
	}
	encoder := json.NewEncoder(entry)
	encoder.SetIndent("", "  ")
	encoder.SetEscapeHTML(false)
	return encoder.Encode(value)
}

func databaseInfo(path string) (int64, bool) {
	if strings.TrimSpace(path) == "" {
		return 0, false
	}
	info, err := os.Stat(path)
	if err != nil || !info.Mode().IsRegular() {
		return 0, false
	}
	return info.Size(), true
}

func summarizeTasks(tasks []download.Task) TaskSummary {
	summary := TaskSummary{Total: len(tasks)}
	for _, task := range tasks {
		switch task.State {
		case download.TaskStateDownloading, download.TaskStateRetrying:
			summary.Active++
		case download.TaskStateQueued:
			summary.Queued++
		case download.TaskStatePaused:
			summary.Paused++
		case download.TaskStateCompleted:
			summary.Completed++
		case download.TaskStateFailed:
			summary.Failed++
		case download.TaskStateCanceled:
			summary.Canceled++
		}
		switch task.Protocol {
		case download.ProtocolBT:
			summary.BitTorrent++
		default:
			summary.HTTP++
		}
	}
	return summary
}

func redactPath(path string) string {
	clean := filepath.Clean(strings.TrimSpace(path))
	if clean == "." || clean == "" {
		return ""
	}
	aliases := []struct {
		root  string
		alias string
	}{
		{root: userHomeDirectory(), alias: "~"},
		{root: os.TempDir(), alias: "$TMPDIR"},
	}
	for _, candidate := range aliases {
		if candidate.root == "" {
			continue
		}
		if relative, ok := relativePath(candidate.root, clean); ok {
			if relative == "." {
				return candidate.alias
			}
			return filepath.Join(candidate.alias, relative)
		}
	}

	base := filepath.Base(clean)
	if base == "." || base == string(filepath.Separator) {
		return "<redacted>"
	}
	return filepath.Join("<redacted>", base)
}

func relativePath(root, path string) (string, bool) {
	relative, err := filepath.Rel(filepath.Clean(root), path)
	if err != nil || relative == ".." || strings.HasPrefix(relative, ".."+string(filepath.Separator)) {
		return "", false
	}
	return relative, true
}

func userHomeDirectory() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	return home
}

var _ Provider = (*Service)(nil)
