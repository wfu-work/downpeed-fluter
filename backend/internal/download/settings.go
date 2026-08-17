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
	ErrInvalidSettings           = errors.New("invalid engine settings")
	ErrInvalidSchedulerSettings  = errors.New("invalid scheduler settings")
	ErrInvalidBTPolicy           = errors.New("invalid BitTorrent policy")
	ErrInvalidFileConflictPolicy = errors.New("invalid file conflict policy")
	ErrSettingsPersistence       = errors.New("engine settings persistence failed")
)

const (
	MinBTPeerConnections     = 1
	MaxBTPeerConnections     = 80
	DefaultBTPeerConnections = 80
	MinConcurrentTasks       = 1
	MaxConcurrentTasks       = 64
	MinAutomaticRetries      = 0
	MaxAutomaticRetries      = 10
)

type FileConflictPolicy string

const (
	FileConflictPolicyFail     FileConflictPolicy = "fail"
	FileConflictPolicyUniquify FileConflictPolicy = "uniquify"
	DefaultFileConflictPolicy                     = FileConflictPolicyFail
)

type SchedulerSettings struct {
	MaxConcurrentTasks int   `json:"maxConcurrentTasks"`
	DownloadRateLimit  int64 `json:"downloadRateLimit"`
	MaxRetries         int   `json:"maxRetries"`
}

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
	DefaultDownloadDirectory string             `json:"defaultDownloadDirectory"`
	FileConflictPolicy       FileConflictPolicy `json:"fileConflictPolicy"`
	Scheduler                SchedulerSettings  `json:"scheduler"`
	BitTorrent               BTPolicySettings   `json:"bitTorrent"`
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
	store                     SettingsStore
	mu                        sync.RWMutex
	settings                  EngineSettings
	applySchedulerSettingsFn  func(SchedulerSettings)
	applyFileConflictPolicyFn func(FileConflictPolicy)
}

type SettingsManagerOption func(*settingsManagerConfig)

type settingsManagerConfig struct {
	defaultScheduler SchedulerSettings
}

func WithDefaultSchedulerSettings(settings SchedulerSettings) SettingsManagerOption {
	return func(config *settingsManagerConfig) {
		config.defaultScheduler = settings
	}
}

func NewSettingsManager(ctx context.Context, store SettingsStore, defaultDirectory string, options ...SettingsManagerOption) (*SettingsManager, error) {
	config := settingsManagerConfig{defaultScheduler: DefaultSchedulerSettings()}
	for _, option := range options {
		if option != nil {
			option(&config)
		}
	}
	defaults, err := validateEngineSettings(EngineSettings{
		DefaultDownloadDirectory: defaultDirectory,
		FileConflictPolicy:       DefaultFileConflictPolicy,
		Scheduler:                config.defaultScheduler,
	})
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
	if stored.FileConflictPolicy == "" {
		stored.FileConflictPolicy = defaults.FileConflictPolicy
	}
	if stored.Scheduler == (SchedulerSettings{}) {
		stored.Scheduler = defaults.Scheduler
	}
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

func (m *SettingsManager) SetFileConflictPolicyApplier(apply func(FileConflictPolicy)) {
	m.mu.Lock()
	m.applyFileConflictPolicyFn = apply
	policy := m.settings.FileConflictPolicy
	m.mu.Unlock()
	if apply != nil {
		apply(policy)
	}
}

func (m *SettingsManager) SetSchedulerSettingsApplier(apply func(SchedulerSettings)) {
	m.mu.Lock()
	m.applySchedulerSettingsFn = apply
	settings := m.settings.Scheduler
	m.mu.Unlock()
	if apply != nil {
		apply(settings)
	}
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
	if m.applySchedulerSettingsFn != nil {
		m.applySchedulerSettingsFn(settings.Scheduler)
	}
	if m.applyFileConflictPolicyFn != nil {
		m.applyFileConflictPolicyFn(settings.FileConflictPolicy)
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
	fileConflictPolicy, err := validateFileConflictPolicy(input.FileConflictPolicy)
	if err != nil {
		return EngineSettings{}, err
	}
	policy, err := normalizeBTPolicySettings(input.BitTorrent)
	if err != nil {
		return EngineSettings{}, err
	}
	scheduler, err := validateSchedulerSettings(input.Scheduler)
	if err != nil {
		return EngineSettings{}, err
	}
	return EngineSettings{
		DefaultDownloadDirectory: directory,
		FileConflictPolicy:       fileConflictPolicy,
		Scheduler:                scheduler,
		BitTorrent:               policy,
	}, nil
}

func validateFileConflictPolicy(input FileConflictPolicy) (FileConflictPolicy, error) {
	switch input {
	case FileConflictPolicyFail, FileConflictPolicyUniquify:
		return input, nil
	default:
		return "", fmt.Errorf("%w: unsupported policy", ErrInvalidFileConflictPolicy)
	}
}

func DefaultSchedulerSettings() SchedulerSettings {
	return SchedulerSettings{
		MaxConcurrentTasks: DefaultMaxConcurrentTasks,
		MaxRetries:         DefaultMaxRetries,
	}
}

func validateSchedulerSettings(input SchedulerSettings) (SchedulerSettings, error) {
	if input.MaxConcurrentTasks < MinConcurrentTasks || input.MaxConcurrentTasks > MaxConcurrentTasks {
		return SchedulerSettings{}, fmt.Errorf("%w: maximum concurrent tasks must be between %d and %d", ErrInvalidSchedulerSettings, MinConcurrentTasks, MaxConcurrentTasks)
	}
	if input.DownloadRateLimit < 0 {
		return SchedulerSettings{}, fmt.Errorf("%w: download rate limit cannot be negative", ErrInvalidSchedulerSettings)
	}
	if input.MaxRetries < MinAutomaticRetries || input.MaxRetries > MaxAutomaticRetries {
		return SchedulerSettings{}, fmt.Errorf("%w: automatic retries must be between %d and %d", ErrInvalidSchedulerSettings, MinAutomaticRetries, MaxAutomaticRetries)
	}
	return input, nil
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
