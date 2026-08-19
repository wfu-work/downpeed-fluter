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
	ErrInvalidProxySettings      = errors.New("invalid proxy settings")
	ErrInvalidFileConflictPolicy = errors.New("invalid file conflict policy")
	ErrSettingsPersistence       = errors.New("engine settings persistence failed")
	ErrProxyConnectionFailed     = errors.New("proxy connection failed")
	ErrProxyAuthenticationFailed = errors.New("proxy authentication failed")
	ErrProxyTestTimeout          = errors.New("proxy test timed out")
)

const (
	MinBTPeerConnections     = 1
	MaxBTPeerConnections     = 80
	DefaultBTPeerConnections = 80
	MinConcurrentTasks       = 1
	MaxConcurrentTasks       = 64
	MinAutomaticRetries      = 0
	MaxAutomaticRetries      = 10
	MinProxyTimeoutSeconds   = 1
	MaxProxyTimeoutSeconds   = 120
	DefaultConnectTimeout    = 10
	DefaultResponseTimeout   = 30
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

type ProxyMode string

const (
	ProxyModeDirect  ProxyMode = "direct"
	ProxyModeSystem  ProxyMode = "system"
	ProxyModeHTTP    ProxyMode = "http"
	ProxyModeSOCKS5  ProxyMode = "socks5"
	DefaultProxyMode           = ProxyModeDirect
)

type ProxySettings struct {
	Mode                         ProxyMode `json:"mode"`
	Host                         string    `json:"host"`
	Port                         int       `json:"port"`
	Username                     string    `json:"username"`
	ConnectTimeoutSeconds        int       `json:"connectTimeoutSeconds"`
	ResponseHeaderTimeoutSeconds int       `json:"responseHeaderTimeoutSeconds"`
}

type ProxyTestResult struct {
	Mode      ProxyMode `json:"mode"`
	LatencyMS int64     `json:"latencyMs"`
}

type ProxyService interface {
	SetPassword(string) error
	Test(context.Context) (ProxyTestResult, error)
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
	Proxy                    ProxySettings      `json:"proxy"`
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
	applyProxySettingsFn      func(ProxySettings)
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
		Proxy:                    DefaultProxySettings(),
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
	if stored.Proxy == (ProxySettings{}) {
		stored.Proxy = defaults.Proxy
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

func (m *SettingsManager) SetProxySettingsApplier(apply func(ProxySettings)) {
	m.mu.Lock()
	m.applyProxySettingsFn = apply
	settings := m.settings.Proxy
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
	if m.applyProxySettingsFn != nil {
		m.applyProxySettingsFn(settings.Proxy)
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
	proxySettings, err := validateProxySettings(input.Proxy)
	if err != nil {
		return EngineSettings{}, err
	}
	return EngineSettings{
		DefaultDownloadDirectory: directory,
		FileConflictPolicy:       fileConflictPolicy,
		Scheduler:                scheduler,
		Proxy:                    proxySettings,
		BitTorrent:               policy,
	}, nil
}

func DefaultProxySettings() ProxySettings {
	return ProxySettings{
		Mode:                         DefaultProxyMode,
		ConnectTimeoutSeconds:        DefaultConnectTimeout,
		ResponseHeaderTimeoutSeconds: DefaultResponseTimeout,
	}
}

func validateProxySettings(input ProxySettings) (ProxySettings, error) {
	if input == (ProxySettings{}) {
		return DefaultProxySettings(), nil
	}
	if input.Mode != ProxyModeDirect && input.Mode != ProxyModeSystem && input.Mode != ProxyModeHTTP && input.Mode != ProxyModeSOCKS5 {
		return ProxySettings{}, fmt.Errorf("%w: unsupported proxy mode", ErrInvalidProxySettings)
	}
	host := strings.TrimSpace(input.Host)
	username := strings.TrimSpace(input.Username)
	if len(host) > 253 || strings.ContainsAny(host, "/?#@") || strings.Contains(host, "://") || hasControlCharacter(host) {
		return ProxySettings{}, fmt.Errorf("%w: proxy host is invalid", ErrInvalidProxySettings)
	}
	if len(username) > 256 || hasControlCharacter(username) {
		return ProxySettings{}, fmt.Errorf("%w: proxy username is invalid", ErrInvalidProxySettings)
	}
	if input.Mode == ProxyModeHTTP || input.Mode == ProxyModeSOCKS5 {
		if host == "" || input.Port < 1 || input.Port > 65535 {
			return ProxySettings{}, fmt.Errorf("%w: a proxy host and port are required", ErrInvalidProxySettings)
		}
	} else if input.Port < 0 || input.Port > 65535 {
		return ProxySettings{}, fmt.Errorf("%w: proxy port is invalid", ErrInvalidProxySettings)
	}
	if input.ConnectTimeoutSeconds < MinProxyTimeoutSeconds || input.ConnectTimeoutSeconds > MaxProxyTimeoutSeconds {
		return ProxySettings{}, fmt.Errorf("%w: connection timeout must be between %d and %d seconds", ErrInvalidProxySettings, MinProxyTimeoutSeconds, MaxProxyTimeoutSeconds)
	}
	if input.ResponseHeaderTimeoutSeconds < MinProxyTimeoutSeconds || input.ResponseHeaderTimeoutSeconds > MaxProxyTimeoutSeconds {
		return ProxySettings{}, fmt.Errorf("%w: response timeout must be between %d and %d seconds", ErrInvalidProxySettings, MinProxyTimeoutSeconds, MaxProxyTimeoutSeconds)
	}
	input.Host = host
	input.Username = username
	return input, nil
}

func hasControlCharacter(value string) bool {
	return strings.IndexFunc(value, func(character rune) bool {
		return character < 0x20 || character == 0x7f
	}) >= 0
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
