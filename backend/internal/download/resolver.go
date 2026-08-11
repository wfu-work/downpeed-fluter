package download

import (
	"context"
	"errors"
)

var (
	ErrInvalidRequest    = errors.New("invalid download resolution request")
	ErrUnsupportedScheme = errors.New("unsupported download URL scheme")
)

// ResolveRequest contains the user-controlled inputs needed to inspect a
// remote download without creating a task.
type ResolveRequest struct {
	URL     string            `json:"url"`
	Headers map[string]string `json:"headers,omitempty"`
}

// Resolution is stable protocol metadata returned to API clients.
// Size is -1 when the remote server does not disclose a total length.
type Resolution struct {
	URL          string `json:"url"`
	FinalURL     string `json:"finalUrl"`
	FileName     string `json:"fileName"`
	Size         int64  `json:"size"`
	ContentType  string `json:"contentType"`
	AcceptRanges bool   `json:"acceptRanges"`
	ETag         string `json:"etag,omitempty"`
	LastModified string `json:"lastModified,omitempty"`
}

// Resolver inspects a download source without transferring its content.
type Resolver interface {
	Resolve(context.Context, ResolveRequest) (Resolution, error)
}
