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
	manager, err := NewSettingsManager(context.Background(), store, defaultDirectory)
	if err != nil {
		t.Fatal(err)
	}
	settings, err := manager.GetSettings(context.Background())
	if err != nil || settings.DefaultDownloadDirectory != defaultDirectory || settings.BitTorrent != DefaultBTPolicySettings() {
		t.Fatalf("defaults = %#v, error = %v", settings, err)
	}
	policy := DefaultBTPolicySettings()
	policy.MaxPeerConnections = 20
	updated, err := manager.UpdateSettings(context.Background(), EngineSettings{
		DefaultDownloadDirectory: selectedDirectory,
		BitTorrent:               policy,
	})
	if err != nil || updated.DefaultDownloadDirectory != selectedDirectory || updated.BitTorrent.MaxPeerConnections != 20 {
		t.Fatalf("updated = %#v, error = %v", updated, err)
	}
	restored, err := NewSettingsManager(context.Background(), store, defaultDirectory)
	if err != nil {
		t.Fatal(err)
	}
	settings, _ = restored.GetSettings(context.Background())
	if settings.DefaultDownloadDirectory != selectedDirectory || settings.BitTorrent.MaxPeerConnections != 20 {
		t.Fatalf("restored = %#v", settings)
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
	if settings.BitTorrent != DefaultBTPolicySettings() || store.settings.BitTorrent != DefaultBTPolicySettings() {
		t.Fatalf("legacy settings were not migrated: manager %#v, store %#v", settings, store.settings)
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
	})
	if !errors.Is(err, ErrInvalidSettings) {
		t.Fatalf("error = %v, want ErrInvalidSettings", err)
	}
	settings, _ := manager.GetSettings(context.Background())
	if settings.DefaultDownloadDirectory != defaultDirectory {
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
