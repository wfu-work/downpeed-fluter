package download

import (
	"context"
	"errors"
	"time"
)

var (
	ErrTaskNotFound        = errors.New("download task not found")
	ErrTaskInvalidState    = errors.New("download task state does not allow this operation")
	ErrTaskRetryNotAllowed = errors.New("download task cannot be retried safely")
	ErrInvalidDestination  = errors.New("invalid download destination")
	ErrDestinationExists   = errors.New("download destination already exists")
	ErrRemoteRejected      = errors.New("remote server rejected download")
	ErrRemoteTemporary     = errors.New("remote server temporarily unavailable")
	ErrRemoteChanged       = errors.New("remote download resource changed")
	ErrResumeNotSupported  = errors.New("remote server does not support safe resume")
	ErrPartialFileChanged  = errors.New("partial download file changed")
	ErrFileConsistency     = errors.New("downloaded file failed consistency checks")
	ErrAtomicPublish       = errors.New("completed download cannot be published atomically")
	ErrTaskFileDelete      = errors.New("downloaded file cannot be deleted")
	ErrTaskPersistence     = errors.New("download task persistence failed")
	ErrTransferPaused      = errors.New("download transfer paused")
	ErrTransferCanceled    = errors.New("download transfer canceled")
	ErrTransferShutdown    = errors.New("download engine shutting down")
	ErrUnsupportedProtocol = errors.New("download protocol is not supported by this task manager")
)

type Protocol string

const (
	ProtocolHTTP Protocol = "http"
	ProtocolBT   Protocol = "bt"
)

type TaskState string

const (
	TaskStateQueued      TaskState = "queued"
	TaskStateDownloading TaskState = "downloading"
	TaskStateRetrying    TaskState = "retrying"
	TaskStatePaused      TaskState = "paused"
	TaskStateCompleted   TaskState = "completed"
	TaskStateFailed      TaskState = "failed"
	TaskStateCanceled    TaskState = "canceled"
)

type CreateTaskRequest struct {
	URL           string            `json:"url"`
	FileName      string            `json:"fileName"`
	SaveDirectory string            `json:"saveDirectory"`
	Headers       map[string]string `json:"headers,omitempty"`
	ExpectedSize  int64             `json:"expectedSize,omitempty"`
	AcceptRanges  bool              `json:"acceptRanges,omitempty"`
	ETag          string            `json:"etag,omitempty"`
	LastModified  string            `json:"lastModified,omitempty"`
}

type TaskError struct {
	Code      string `json:"code"`
	Message   string `json:"message"`
	Retryable bool   `json:"retryable"`
}

type Task struct {
	ID            string     `json:"id"`
	Protocol      Protocol   `json:"protocol"`
	URL           string     `json:"url"`
	FinalURL      string     `json:"finalUrl"`
	FileName      string     `json:"fileName"`
	SaveDirectory string     `json:"saveDirectory"`
	FilePath      string     `json:"filePath"`
	State         TaskState  `json:"state"`
	Downloaded    int64      `json:"downloaded"`
	Total         int64      `json:"total"`
	SpeedBPS      int64      `json:"speedBps"`
	Connections   int        `json:"connections,omitempty"`
	RetryCount    int        `json:"retryCount,omitempty"`
	NextRetryAt   *time.Time `json:"nextRetryAt,omitempty"`
	Error         *TaskError `json:"error,omitempty"`
	CreatedAt     time.Time  `json:"createdAt"`
	UpdatedAt     time.Time  `json:"updatedAt"`
	CompletedAt   *time.Time `json:"completedAt,omitempty"`
}

type TaskEvent struct {
	Type string `json:"type"`
	Task Task   `json:"task"`
}

const TaskUpdatedEvent = "task.updated"
const TaskRemovedEvent = "task.removed"

type DeleteTaskResult struct {
	ID          string `json:"id"`
	FileDeleted bool   `json:"fileDeleted"`
}

type TransferRequest struct {
	URL           string
	Headers       map[string]string
	Destination   string
	WorkPath      string
	Offset        int64
	ExpectedSize  int64
	AcceptRanges  bool
	AllowSegments bool
	Validator     ResourceValidator
	Checkpoint    *TransferCheckpoint
	Limiter       BandwidthLimiter
}

type TransferProgress struct {
	Downloaded int64
	Total      int64
	SpeedBPS   int64
	Checkpoint *TransferCheckpoint
}

type TransferResult struct {
	FinalURL string
	Size     int64
}

type Transfer interface {
	Download(context.Context, TransferRequest, func(TransferProgress)) (TransferResult, error)
}

type StoredTask struct {
	Task         Task                `json:"task"`
	Headers      map[string]string   `json:"headers,omitempty"`
	AcceptRanges bool                `json:"acceptRanges,omitempty"`
	Validator    ResourceValidator   `json:"validator,omitempty"`
	Checkpoint   *TransferCheckpoint `json:"checkpoint,omitempty"`
	BT           *StoredBTTask       `json:"bt,omitempty"`
}

type TaskStore interface {
	Load(context.Context) ([]StoredTask, error)
	Save(context.Context, StoredTask) error
	Delete(context.Context, string) error
	Close() error
}

type TaskService interface {
	Create(context.Context, CreateTaskRequest) (Task, error)
	List(context.Context) ([]Task, error)
	Get(context.Context, string) (Task, error)
	Pause(context.Context, string) (Task, error)
	Resume(context.Context, string) (Task, error)
	Retry(context.Context, string) (Task, error)
	Cancel(context.Context, string) (Task, error)
	Delete(context.Context, string, bool) (DeleteTaskResult, error)
	Subscribe(context.Context) <-chan TaskEvent
}
