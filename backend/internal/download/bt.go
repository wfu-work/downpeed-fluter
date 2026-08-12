package download

import (
	"context"
	"errors"
	"time"
)

var (
	ErrBTInvalidMagnet    = errors.New("invalid magnet URI")
	ErrBTMetadataInvalid  = errors.New("invalid torrent metadata")
	ErrBTMetadataTooLarge = errors.New("torrent metadata is too large")
	ErrBTPathUnsafe       = errors.New("torrent path is unsafe")
	ErrBTFileLimit        = errors.New("torrent contains too many files")
	ErrBTSizeLimit        = errors.New("torrent declared size is too large")
	ErrBTTrackerInvalid   = errors.New("torrent tracker is invalid")
	ErrBTPeerRequired     = errors.New("at least one explicit BT peer is required")
	ErrBTPeerInvalid      = errors.New("explicit BT peer is invalid or restricted")
	ErrBTFileSelection    = errors.New("BT file selection is invalid")
)

const (
	MaxTorrentMetadataBytes = 8 << 20
	MaxMagnetURIBytes       = 8 << 10
	MaxTorrentFiles         = 10_000
	MaxTorrentPathDepth     = 32
	MaxTorrentPathSegment   = 255
	MaxTorrentTrackers      = 64
	MaxTorrentTrackerBytes  = 2 << 10
	MaxTorrentFileSize      = int64(8) << 40
	MaxTorrentTotalSize     = int64(16) << 40
)

type BTSourceType string

const (
	BTSourceMagnet  BTSourceType = "magnet"
	BTSourceTorrent BTSourceType = "torrent"
)

type BTFile struct {
	Index int    `json:"index"`
	Path  string `json:"path"`
	Size  int64  `json:"size"`
}

type BTTracker struct {
	Scheme string `json:"scheme"`
	Host   string `json:"host"`
}

type BTResolution struct {
	SourceType        BTSourceType `json:"sourceType"`
	Name              string       `json:"name"`
	InfoHash          string       `json:"infoHash,omitempty"`
	V2InfoHash        string       `json:"v2InfoHash,omitempty"`
	MetadataAvailable bool         `json:"metadataAvailable"`
	Private           bool         `json:"private"`
	TotalSize         int64        `json:"totalSize"`
	PieceLength       int64        `json:"pieceLength"`
	Files             []BTFile     `json:"files"`
	Trackers          []BTTracker  `json:"trackers"`
}

type BTResolver interface {
	ResolveMagnet(context.Context, string) (BTResolution, error)
	ResolveTorrent(context.Context, []byte) (BTResolution, error)
}

type CreateBTTaskRequest struct {
	Metadata            []byte   `json:"metadata"`
	SaveDirectory       string   `json:"saveDirectory"`
	SelectedFileIndexes []int    `json:"selectedFileIndexes"`
	ExplicitPeers       []string `json:"explicitPeers"`
}

type BTTransferRequest struct {
	Metadata            []byte
	SaveDirectory       string
	Name                string
	Identity            string
	Total               int64
	SelectedFileIndexes []int
	ExplicitPeers       []string
	Files               []BTFile
	Policy              BTPolicySettings
}

type BTTransferProgress struct {
	Downloaded  int64
	Total       int64
	SpeedBPS    int64
	Connections int
	Diagnostics BTDiagnostics
}

type BTTransferResult struct {
	Size int64
}

type BTTransfer interface {
	Prepare(context.Context, CreateBTTaskRequest) (BTTransferRequest, error)
	Download(context.Context, BTTransferRequest, func(BTTransferProgress)) (BTTransferResult, error)
	Cleanup(context.Context, BTTransferRequest) error
}

type BTTaskCreator interface {
	CreateBT(context.Context, CreateBTTaskRequest) (Task, error)
}

type BTDiagnosticsService interface {
	GetBTDiagnostics(context.Context, string) (BTDiagnostics, error)
}

type BTConnectionDiagnostics struct {
	Configured int `json:"configured"`
	Known      int `json:"known"`
	Connected  int `json:"connected"`
	Pending    int `json:"pending"`
	HalfOpen   int `json:"halfOpen"`
	Seeders    int `json:"seeders"`
}

type BTTrafficDiagnostics struct {
	ReceivedBytes  int64 `json:"receivedBytes"`
	UsefulBytes    int64 `json:"usefulBytes"`
	UploadedBytes  int64 `json:"uploadedBytes"`
	WastedChunks   int64 `json:"wastedChunks"`
	VerifiedPieces int64 `json:"verifiedPieces"`
	FailedPieces   int64 `json:"failedPieces"`
}

type BTPeerDiagnostics struct {
	Address         string `json:"address"`
	Client          string `json:"client"`
	Network         string `json:"network"`
	ReceivedBytes   int64  `json:"receivedBytes"`
	DownloadRateBPS int64  `json:"downloadRateBps"`
	VerifiedPieces  int64  `json:"verifiedPieces"`
	FailedPieces    int64  `json:"failedPieces"`
}

type BTPolicyDiagnostics struct {
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

type BTDiagnostics struct {
	TaskID      string                  `json:"taskId"`
	State       TaskState               `json:"state"`
	Live        bool                    `json:"live"`
	Connections BTConnectionDiagnostics `json:"connections"`
	Traffic     BTTrafficDiagnostics    `json:"traffic"`
	Peers       []BTPeerDiagnostics     `json:"peers"`
	Policy      BTPolicyDiagnostics     `json:"policy"`
	UpdatedAt   time.Time               `json:"updatedAt"`
}

type StoredBTTask struct {
	Metadata            []byte           `json:"metadata"`
	Name                string           `json:"name"`
	Identity            string           `json:"identity"`
	Total               int64            `json:"total"`
	Files               []BTFile         `json:"files"`
	SelectedFileIndexes []int            `json:"selectedFileIndexes"`
	ExplicitPeers       []string         `json:"explicitPeers"`
	Policy              BTPolicySettings `json:"policy"`
}

func CloneStoredBTTask(value *StoredBTTask) *StoredBTTask {
	if value == nil {
		return nil
	}
	copyValue := *value
	copyValue.Metadata = append([]byte(nil), value.Metadata...)
	copyValue.Files = append([]BTFile(nil), value.Files...)
	copyValue.SelectedFileIndexes = append([]int(nil), value.SelectedFileIndexes...)
	copyValue.ExplicitPeers = append([]string(nil), value.ExplicitPeers...)
	return &copyValue
}
