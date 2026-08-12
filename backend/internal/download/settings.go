package download

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
)

var (
	ErrInvalidSettings     = errors.New("invalid engine settings")
	ErrInvalidBTPolicy     = errors.New("invalid BitTorrent policy")
	ErrSettingsPersistence = errors.New("engine settings persistence failed")
)

const (
	MinBTPeerConnections     = 1
	MaxBTPeerConnections     = 80
	DefaultBTPeerConnections = 80
)

type BTPolicySettings struct {
	MaxPeerConnections int  `json:"maxPeerConnections"`
	ExplicitPeersOnly  bool `json:"explicitPeersOnly"`
	TrackersEnabled    bool `json:"trackersEnabled"`
	DHTEnabled         bool `json:"dhtEnabled"`
	PEXEnabled         bool `json:"pexEnabled"`
	WebSeedsEnabled    bool `json:"webSeedsEnabled"`
	InboundEnabled     bool `json:"inboundEnabled"`
	IPv6Enabled        bool `json:"ipv6Enabled"`
	UploadEnabled      bool `json:"uploadEnabled"`
	SeedingEnabled     bool `json:"seedingEnabled"`
}

type EngineSettings struct {
	DefaultDownloadDirectory string           `json:"defaultDownloadDirectory"`
	BitTorrent               BTPolicySettings `json:"bitTorrent"`
}

type SettingsStore interface {
	LoadSettings(context.Context) (EngineSettings, error)
	SaveSettings(context.Context, EngineSettings) error
}

type SettingsService interface {
	GetSettings(context.Context) (EngineSettings, error)
	UpdateSettings(context.Context, EngineSettings) (EngineSettings, error)
}

type SettingsManager struct {
	store    SettingsStore
	mu       sync.RWMutex
	settings EngineSettings
}

func NewSettingsManager(ctx context.Context, store SettingsStore, defaultDirectory string) (*SettingsManager, error) {
	defaults, err := validateEngineSettings(EngineSettings{DefaultDownloadDirectory: defaultDirectory})
	if err != nil {
		return nil, err
	}
	manager := &SettingsManager{store: store, settings: defaults}
	if store == nil {
		return manager, nil
	}
	stored, err := store.LoadSettings(ctx)
	if err != nil {
		return nil, err
	}
	if strings.TrimSpace(stored.DefaultDownloadDirectory) == "" {
		if err = store.SaveSettings(ctx, defaults); err != nil {
			return nil, err
		}
		return manager, nil
	}
	storedInput := stored
	stored, err = validateEngineSettings(stored)
	if err != nil {
		if err = store.SaveSettings(ctx, defaults); err != nil {
			return nil, err
		}
		return manager, nil
	}
	if stored != storedInput {
		if err = store.SaveSettings(ctx, stored); err != nil {
			return nil, err
		}
	}
	manager.settings = stored
	return manager, nil
}

func (m *SettingsManager) GetSettings(ctx context.Context) (EngineSettings, error) {
	if err := ctx.Err(); err != nil {
		return EngineSettings{}, err
	}
	m.mu.RLock()
	settings := m.settings
	m.mu.RUnlock()
	return settings, nil
}

func (m *SettingsManager) UpdateSettings(ctx context.Context, input EngineSettings) (EngineSettings, error) {
	settings, err := validateEngineSettings(input)
	if err != nil {
		return EngineSettings{}, err
	}
	if err = ctx.Err(); err != nil {
		return EngineSettings{}, err
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.store != nil {
		if err = m.store.SaveSettings(ctx, settings); err != nil {
			return EngineSettings{}, err
		}
	}
	m.settings = settings
	return settings, nil
}

func validateEngineSettings(input EngineSettings) (EngineSettings, error) {
	directory := filepath.Clean(strings.TrimSpace(input.DefaultDownloadDirectory))
	if !filepath.IsAbs(directory) {
		return EngineSettings{}, fmt.Errorf("%w: default download directory must be absolute", ErrInvalidSettings)
	}
	info, err := os.Stat(directory)
	if err != nil || !info.IsDir() {
		return EngineSettings{}, fmt.Errorf("%w: default download directory is unavailable", ErrInvalidSettings)
	}
	policy, err := normalizeBTPolicySettings(input.BitTorrent)
	if err != nil {
		return EngineSettings{}, err
	}
	return EngineSettings{
		DefaultDownloadDirectory: directory,
		BitTorrent:               policy,
	}, nil
}

func DefaultBTPolicySettings() BTPolicySettings {
	return BTPolicySettings{
		MaxPeerConnections: DefaultBTPeerConnections,
		ExplicitPeersOnly:  true,
	}
}

func normalizeBTPolicySettings(input BTPolicySettings) (BTPolicySettings, error) {
	if input == (BTPolicySettings{}) {
		return DefaultBTPolicySettings(), nil
	}
	if input.MaxPeerConnections < MinBTPeerConnections || input.MaxPeerConnections > MaxBTPeerConnections {
		return BTPolicySettings{}, fmt.Errorf("%w: peer connection budget must be between %d and %d", ErrInvalidBTPolicy, MinBTPeerConnections, MaxBTPeerConnections)
	}
	if !input.ExplicitPeersOnly || input.TrackersEnabled || input.DHTEnabled || input.PEXEnabled || input.WebSeedsEnabled || input.InboundEnabled || input.IPv6Enabled || input.UploadEnabled || input.SeedingEnabled {
		return BTPolicySettings{}, fmt.Errorf("%w: restricted network capabilities cannot be enabled", ErrInvalidBTPolicy)
	}
	return input, nil
}

var _ SettingsService = (*SettingsManager)(nil)
