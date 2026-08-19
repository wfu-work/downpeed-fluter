package download

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"
)

func TestSettingsManagerUsesUpdatesAndPersistsDefaultDirectory(t *testing.T) {
	root := t.TempDir()
	defaultDirectory := filepath.Join(root, "Downloads")
	selectedDirectory := filepath.Join(root, "Selected")
	if err := makeTestDirectories(defaultDirectory, selectedDirectory); err != nil {
		t.Fatal(err)
	}
	store := &memorySettingsStore{}
	defaultScheduler := SchedulerSettings{
		MaxConcurrentTasks: 5,
		DownloadRateLimit:  5 * 1024 * 1024,
		MaxRetries:         4,
	}
	manager, err := NewSettingsManager(
		context.Background(),
		store,
		defaultDirectory,
		WithDefaultSchedulerSettings(defaultScheduler),
	)
	if err != nil {
		t.Fatal(err)
	}
	settings, err := manager.GetSettings(context.Background())
	if err != nil || settings.DefaultDownloadDirectory != defaultDirectory || settings.FileConflictPolicy != DefaultFileConflictPolicy || settings.Scheduler != defaultScheduler || settings.Proxy != DefaultProxySettings() || settings.BitTorrent != DefaultBTPolicySettings() {
		t.Fatalf("defaults = %#v, error = %v", settings, err)
	}
	policy := DefaultBTPolicySettings()
	policy.MaxPeerConnections = 20
	updatedScheduler := SchedulerSettings{
		MaxConcurrentTasks: 2,
		DownloadRateLimit:  1024 * 1024,
		MaxRetries:         1,
	}
	updatedProxy := ProxySettings{
		Mode:                         ProxyModeSOCKS5,
		Host:                         "127.0.0.1",
		Port:                         1080,
		Username:                     "downpeed",
		ConnectTimeoutSeconds:        8,
		ResponseHeaderTimeoutSeconds: 20,
	}
	updated, err := manager.UpdateSettings(context.Background(), EngineSettings{
		DefaultDownloadDirectory: selectedDirectory,
		FileConflictPolicy:       FileConflictPolicyUniquify,
		Scheduler:                updatedScheduler,
		Proxy:                    updatedProxy,
		BitTorrent:               policy,
	})
	if err != nil || updated.DefaultDownloadDirectory != selectedDirectory || updated.FileConflictPolicy != FileConflictPolicyUniquify || updated.Scheduler != updatedScheduler || updated.Proxy != updatedProxy || updated.BitTorrent.MaxPeerConnections != 20 {
		t.Fatalf("updated = %#v, error = %v", updated, err)
	}
	restored, err := NewSettingsManager(context.Background(), store, defaultDirectory)
	if err != nil {
		t.Fatal(err)
	}
	settings, _ = restored.GetSettings(context.Background())
	if settings.DefaultDownloadDirectory != selectedDirectory || settings.FileConflictPolicy != FileConflictPolicyUniquify || settings.Scheduler != updatedScheduler || settings.Proxy != updatedProxy || settings.BitTorrent.MaxPeerConnections != 20 {
		t.Fatalf("restored = %#v", settings)
	}
}

func TestSettingsManagerAppliesSchedulerSettingsAfterPersistence(t *testing.T) {
	directory := t.TempDir()
	store := &memorySettingsStore{}
	manager, err := NewSettingsManager(context.Background(), store, directory)
	if err != nil {
		t.Fatal(err)
	}
	applied := make([]SchedulerSettings, 0, 2)
	manager.SetSchedulerSettingsApplier(func(settings SchedulerSettings) {
		applied = append(applied, settings)
	})
	updated := SchedulerSettings{MaxConcurrentTasks: 1, DownloadRateLimit: 2048, MaxRetries: 0}
	if _, err = manager.UpdateSettings(context.Background(), EngineSettings{
		DefaultDownloadDirectory: directory,
		FileConflictPolicy:       DefaultFileConflictPolicy,
		Scheduler:                updated,
		BitTorrent:               DefaultBTPolicySettings(),
	}); err != nil {
		t.Fatal(err)
	}
	if len(applied) != 2 || applied[0] != DefaultSchedulerSettings() || applied[1] != updated {
		t.Fatalf("applied scheduler settings = %#v", applied)
	}
}

func TestSettingsManagerAppliesFileConflictPolicyAfterPersistence(t *testing.T) {
	directory := t.TempDir()
	manager, err := NewSettingsManager(context.Background(), &memorySettingsStore{}, directory)
	if err != nil {
		t.Fatal(err)
	}
	applied := make([]FileConflictPolicy, 0, 2)
	manager.SetFileConflictPolicyApplier(func(policy FileConflictPolicy) {
		applied = append(applied, policy)
	})
	if _, err = manager.UpdateSettings(context.Background(), EngineSettings{
		DefaultDownloadDirectory: directory,
		FileConflictPolicy:       FileConflictPolicyUniquify,
		Scheduler:                DefaultSchedulerSettings(),
		BitTorrent:               DefaultBTPolicySettings(),
	}); err != nil {
		t.Fatal(err)
	}
	if len(applied) != 2 || applied[0] != FileConflictPolicyFail || applied[1] != FileConflictPolicyUniquify {
		t.Fatalf("applied file conflict policies = %#v", applied)
	}
}

func TestSettingsManagerAppliesProxySettingsAfterPersistence(t *testing.T) {
	directory := t.TempDir()
	manager, err := NewSettingsManager(context.Background(), &memorySettingsStore{}, directory)
	if err != nil {
		t.Fatal(err)
	}
	applied := make([]ProxySettings, 0, 2)
	manager.SetProxySettingsApplier(func(settings ProxySettings) {
		applied = append(applied, settings)
	})
	proxySettings := ProxySettings{
		Mode:                         ProxyModeHTTP,
		Host:                         "proxy.example",
		Port:                         8080,
		Username:                     "user",
		ConnectTimeoutSeconds:        5,
		ResponseHeaderTimeoutSeconds: 15,
	}
	if _, err = manager.UpdateSettings(context.Background(), EngineSettings{
		DefaultDownloadDirectory: directory,
		FileConflictPolicy:       DefaultFileConflictPolicy,
		Scheduler:                DefaultSchedulerSettings(),
		Proxy:                    proxySettings,
		BitTorrent:               DefaultBTPolicySettings(),
	}); err != nil {
		t.Fatal(err)
	}
	if len(applied) != 2 || applied[0] != DefaultProxySettings() || applied[1] != proxySettings {
		t.Fatalf("applied proxy settings = %#v", applied)
	}
}

func TestSettingsManagerRejectsUnsafeBTPolicyAndKeepsPreviousValue(t *testing.T) {
	directory := t.TempDir()
	manager, err := NewSettingsManager(context.Background(), nil, directory)
	if err != nil {
		t.Fatal(err)
	}
	unsafe := DefaultBTPolicySettings()
	unsafe.TrackersEnabled = true
	_, err = manager.UpdateSettings(context.Background(), EngineSettings{
		DefaultDownloadDirectory: directory,
		FileConflictPolicy:       DefaultFileConflictPolicy,
		Scheduler:                DefaultSchedulerSettings(),
		BitTorrent:               unsafe,
	})
	if !errors.Is(err, ErrInvalidBTPolicy) {
		t.Fatalf("error = %v, want ErrInvalidBTPolicy", err)
	}
	settings, _ := manager.GetSettings(context.Background())
	if settings.BitTorrent != DefaultBTPolicySettings() {
		t.Fatalf("settings changed after rejection: %#v", settings)
	}
}

func TestSettingsManagerRejectsOutOfRangeBTPeerBudget(t *testing.T) {
	directory := t.TempDir()
	manager, err := NewSettingsManager(context.Background(), nil, directory)
	if err != nil {
		t.Fatal(err)
	}
	policy := DefaultBTPolicySettings()
	policy.MaxPeerConnections = MaxBTPeerConnections + 1
	_, err = manager.UpdateSettings(context.Background(), EngineSettings{
		DefaultDownloadDirectory: directory,
		FileConflictPolicy:       DefaultFileConflictPolicy,
		Scheduler:                DefaultSchedulerSettings(),
		BitTorrent:               policy,
	})
	if !errors.Is(err, ErrInvalidBTPolicy) {
		t.Fatalf("error = %v, want ErrInvalidBTPolicy", err)
	}
}

func TestSettingsManagerMigratesLegacySettingsToRestrictedBTDefaults(t *testing.T) {
	directory := t.TempDir()
	store := &memorySettingsStore{settings: EngineSettings{
		DefaultDownloadDirectory: directory,
	}}
	manager, err := NewSettingsManager(context.Background(), store, directory)
	if err != nil {
		t.Fatal(err)
	}
	settings, _ := manager.GetSettings(context.Background())
	if settings.FileConflictPolicy != DefaultFileConflictPolicy || store.settings.FileConflictPolicy != DefaultFileConflictPolicy || settings.Scheduler != DefaultSchedulerSettings() || store.settings.Scheduler != DefaultSchedulerSettings() || settings.Proxy != DefaultProxySettings() || store.settings.Proxy != DefaultProxySettings() || settings.BitTorrent != DefaultBTPolicySettings() || store.settings.BitTorrent != DefaultBTPolicySettings() {
		t.Fatalf("legacy settings were not migrated: manager %#v, store %#v", settings, store.settings)
	}
}

func TestSettingsManagerRejectsInvalidProxySettingsAndKeepsPreviousValue(t *testing.T) {
	directory := t.TempDir()
	manager, err := NewSettingsManager(context.Background(), nil, directory)
	if err != nil {
		t.Fatal(err)
	}
	tests := []ProxySettings{
		{Mode: ProxyMode("ftp"), ConnectTimeoutSeconds: 10, ResponseHeaderTimeoutSeconds: 30},
		{Mode: ProxyModeHTTP, Host: "https://proxy.example", Port: 8080, ConnectTimeoutSeconds: 10, ResponseHeaderTimeoutSeconds: 30},
		{Mode: ProxyModeSOCKS5, Host: "proxy.example", Port: 0, ConnectTimeoutSeconds: 10, ResponseHeaderTimeoutSeconds: 30},
		{Mode: ProxyModeDirect, ConnectTimeoutSeconds: 0, ResponseHeaderTimeoutSeconds: 30},
		{Mode: ProxyModeSystem, ConnectTimeoutSeconds: 10, ResponseHeaderTimeoutSeconds: MaxProxyTimeoutSeconds + 1},
	}
	for _, proxySettings := range tests {
		_, err = manager.UpdateSettings(context.Background(), EngineSettings{
			DefaultDownloadDirectory: directory,
			FileConflictPolicy:       DefaultFileConflictPolicy,
			Scheduler:                DefaultSchedulerSettings(),
			Proxy:                    proxySettings,
			BitTorrent:               DefaultBTPolicySettings(),
		})
		if !errors.Is(err, ErrInvalidProxySettings) {
			t.Fatalf("proxy %#v error = %v, want ErrInvalidProxySettings", proxySettings, err)
		}
	}
	settings, _ := manager.GetSettings(context.Background())
	if settings.Proxy != DefaultProxySettings() {
		t.Fatalf("settings changed after rejection: %#v", settings)
	}
}

func TestSettingsManagerRejectsInvalidSchedulerSettings(t *testing.T) {
	directory := t.TempDir()
	manager, err := NewSettingsManager(context.Background(), nil, directory)
	if err != nil {
		t.Fatal(err)
	}
	tests := []SchedulerSettings{
		{MaxConcurrentTasks: 0, MaxRetries: DefaultMaxRetries},
		{MaxConcurrentTasks: MaxConcurrentTasks + 1, MaxRetries: DefaultMaxRetries},
		{MaxConcurrentTasks: DefaultMaxConcurrentTasks, DownloadRateLimit: -1, MaxRetries: DefaultMaxRetries},
		{MaxConcurrentTasks: DefaultMaxConcurrentTasks, MaxRetries: MaxAutomaticRetries + 1},
	}
	for _, scheduler := range tests {
		_, err = manager.UpdateSettings(context.Background(), EngineSettings{
			DefaultDownloadDirectory: directory,
			FileConflictPolicy:       DefaultFileConflictPolicy,
			Scheduler:                scheduler,
			BitTorrent:               DefaultBTPolicySettings(),
		})
		if !errors.Is(err, ErrInvalidSchedulerSettings) {
			t.Fatalf("scheduler %#v error = %v, want ErrInvalidSchedulerSettings", scheduler, err)
		}
	}
	settings, _ := manager.GetSettings(context.Background())
	if settings.Scheduler != DefaultSchedulerSettings() {
		t.Fatalf("settings changed after rejection: %#v", settings)
	}
}

func TestSettingsManagerRejectsUnavailableDirectoryAndKeepsPreviousValue(t *testing.T) {
	defaultDirectory := t.TempDir()
	manager, err := NewSettingsManager(context.Background(), nil, defaultDirectory)
	if err != nil {
		t.Fatal(err)
	}
	_, err = manager.UpdateSettings(context.Background(), EngineSettings{
		DefaultDownloadDirectory: filepath.Join(defaultDirectory, "missing"),
		FileConflictPolicy:       DefaultFileConflictPolicy,
		Scheduler:                DefaultSchedulerSettings(),
		BitTorrent:               DefaultBTPolicySettings(),
	})
	if !errors.Is(err, ErrInvalidSettings) {
		t.Fatalf("error = %v, want ErrInvalidSettings", err)
	}
	settings, _ := manager.GetSettings(context.Background())
	if settings.DefaultDownloadDirectory != defaultDirectory {
		t.Fatalf("settings changed after rejection: %#v", settings)
	}
}

func TestSettingsManagerRejectsInvalidFileConflictPolicy(t *testing.T) {
	directory := t.TempDir()
	manager, err := NewSettingsManager(context.Background(), nil, directory)
	if err != nil {
		t.Fatal(err)
	}
	_, err = manager.UpdateSettings(context.Background(), EngineSettings{
		DefaultDownloadDirectory: directory,
		FileConflictPolicy:       FileConflictPolicy("overwrite"),
		Scheduler:                DefaultSchedulerSettings(),
		BitTorrent:               DefaultBTPolicySettings(),
	})
	if !errors.Is(err, ErrInvalidFileConflictPolicy) {
		t.Fatalf("error = %v, want ErrInvalidFileConflictPolicy", err)
	}
	settings, _ := manager.GetSettings(context.Background())
	if settings.FileConflictPolicy != DefaultFileConflictPolicy {
		t.Fatalf("settings changed after rejection: %#v", settings)
	}
}

type memorySettingsStore struct {
	settings EngineSettings
}

func (s *memorySettingsStore) LoadSettings(context.Context) (EngineSettings, error) {
	return s.settings, nil
}

func (s *memorySettingsStore) SaveSettings(_ context.Context, settings EngineSettings) error {
	s.settings = settings
	return nil
}

func makeTestDirectories(paths ...string) error {
	for _, path := range paths {
		if err := os.MkdirAll(path, 0o755); err != nil {
			return err
		}
	}
	return nil
}
