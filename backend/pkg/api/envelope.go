package api

// Error is the stable error shape exposed to Downpeed clients.
type Error struct {
	Code      string         `json:"code"`
	Message   string         `json:"message"`
	Retryable bool           `json:"retryable"`
	Details   map[string]any `json:"details,omitempty"`
}

// Envelope keeps successful and failed responses structurally consistent.
type Envelope[T any] struct {
	Data      T      `json:"data"`
	Error     *Error `json:"error"`
	RequestID string `json:"requestId"`
}
