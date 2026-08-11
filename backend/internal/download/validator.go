package download

import (
	"fmt"
	"net/http"
	"strings"
)

// ResourceValidator identifies the remote representation inspected before a
// task starts. A strong ETag is preferred for byte-range validation; a valid
// Last-Modified date is the fallback accepted by HTTP If-Range.
type ResourceValidator struct {
	ETag         string `json:"etag,omitempty"`
	LastModified string `json:"lastModified,omitempty"`
}

func ParseResourceValidator(etag, lastModified string) ResourceValidator {
	validator := ResourceValidator{}
	if normalized, ok := normalizeETag(etag); ok {
		validator.ETag = normalized
	}
	if normalized, ok := normalizeHTTPDate(lastModified); ok {
		validator.LastModified = normalized
	}
	return validator
}

func NormalizeResourceValidator(etag, lastModified string) (ResourceValidator, error) {
	validator := ParseResourceValidator(etag, lastModified)
	if strings.TrimSpace(etag) != "" && validator.ETag == "" {
		return ResourceValidator{}, fmt.Errorf("%w: ETag is malformed", ErrInvalidRequest)
	}
	if strings.TrimSpace(lastModified) != "" && validator.LastModified == "" {
		return ResourceValidator{}, fmt.Errorf("%w: Last-Modified is malformed", ErrInvalidRequest)
	}
	return validator, nil
}

func (validator ResourceValidator) StrongETag() string {
	if validator.ETag == "" || strings.HasPrefix(validator.ETag, "W/") {
		return ""
	}
	return validator.ETag
}

func (validator ResourceValidator) IfRangeValue() string {
	if etag := validator.StrongETag(); etag != "" {
		return etag
	}
	return validator.LastModified
}

func (validator ResourceValidator) IsZero() bool {
	return validator.ETag == "" && validator.LastModified == ""
}

func normalizeETag(value string) (string, bool) {
	value = strings.TrimSpace(value)
	if strings.HasPrefix(value, "W/") {
		value = strings.TrimPrefix(value, "W/")
		if !validOpaqueETag(value) {
			return "", false
		}
		return "W/" + value, true
	}
	if !validOpaqueETag(value) {
		return "", false
	}
	return value, true
}

func validOpaqueETag(value string) bool {
	if len(value) < 2 || value[0] != '"' || value[len(value)-1] != '"' {
		return false
	}
	for index := 1; index < len(value)-1; index++ {
		character := value[index]
		if character == '"' || character < 0x21 || character == 0x7f {
			return false
		}
	}
	return true
}

func normalizeHTTPDate(value string) (string, bool) {
	value = strings.TrimSpace(value)
	if value == "" {
		return "", false
	}
	parsed, err := http.ParseTime(value)
	if err != nil {
		return "", false
	}
	return parsed.UTC().Format(http.TimeFormat), true
}
