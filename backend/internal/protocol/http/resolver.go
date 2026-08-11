package httpprotocol

import (
	"context"
	"fmt"
	"mime"
	nethttp "net/http"
	"net/url"
	"path"
	"strconv"
	"strings"
	"time"

	"github.com/wfu-work/downpeed-fluter/backend/internal/download"
)

const defaultResolveTimeout = 12 * time.Second

type Resolver struct {
	client *nethttp.Client
}

func NewResolver(client *nethttp.Client) *Resolver {
	if client == nil {
		client = &nethttp.Client{Timeout: defaultResolveTimeout}
	}
	return &Resolver{client: client}
}

func (r *Resolver) Resolve(ctx context.Context, input download.ResolveRequest) (download.Resolution, error) {
	parsedURL, err := validateURL(input.URL)
	if err != nil {
		return download.Resolution{}, err
	}

	head, err := r.request(ctx, nethttp.MethodHead, parsedURL, input.Headers)
	if err != nil {
		return download.Resolution{}, fmt.Errorf("probe download with HEAD: %w", err)
	}

	metadata := responseMetadata{size: -1}
	needsRangeProbe := false
	switch {
	case head.status == nethttp.StatusMethodNotAllowed || head.status == nethttp.StatusNotImplemented:
		needsRangeProbe = true
	case head.status >= 200 && head.status < 300:
		metadata = head.metadata
		needsRangeProbe = metadata.size < 0 || !metadata.acceptRanges || metadata.validator.IfRangeValue() == ""
	default:
		return download.Resolution{}, fmt.Errorf("probe download with HEAD: unexpected HTTP status %d", head.status)
	}

	if needsRangeProbe {
		rangeProbe, probeErr := r.request(ctx, nethttp.MethodGet, parsedURL, withRangeHeader(input.Headers))
		if probeErr != nil {
			return download.Resolution{}, fmt.Errorf("probe download with Range: %w", probeErr)
		}
		if probeErr = mergeRangeProbe(&metadata, rangeProbe); probeErr != nil {
			return download.Resolution{}, probeErr
		}
	}

	finalURL := parsedURL
	if metadata.finalURL != nil {
		finalURL = metadata.finalURL
	}
	fileName := download.SafeFileName(metadata.fileName)
	if fileName == "" {
		fileName = fileNameFromURL(finalURL)
	}
	if fileName == "" {
		fileName = "download"
	}

	return download.Resolution{
		URL:          parsedURL.String(),
		FinalURL:     finalURL.String(),
		FileName:     fileName,
		Size:         metadata.size,
		ContentType:  metadata.contentType,
		AcceptRanges: metadata.acceptRanges,
		ETag:         metadata.validator.ETag,
		LastModified: metadata.validator.LastModified,
	}, nil
}

type probeResponse struct {
	status   int
	metadata responseMetadata
}

type responseMetadata struct {
	finalURL     *url.URL
	fileName     string
	size         int64
	contentType  string
	acceptRanges bool
	contentRange string
	validator    download.ResourceValidator
}

func (r *Resolver) request(
	ctx context.Context,
	method string,
	target *url.URL,
	headers map[string]string,
) (probeResponse, error) {
	request, err := nethttp.NewRequestWithContext(ctx, method, target.String(), nil)
	if err != nil {
		return probeResponse{}, err
	}
	for name, value := range headers {
		request.Header.Set(name, value)
	}
	request.Header.Set("Accept-Encoding", "identity")

	response, err := r.client.Do(request)
	if err != nil {
		return probeResponse{}, err
	}
	defer response.Body.Close()

	metadata := responseMetadata{
		finalURL:     response.Request.URL,
		fileName:     fileNameFromDisposition(response.Header.Get("Content-Disposition")),
		size:         response.ContentLength,
		contentType:  response.Header.Get("Content-Type"),
		acceptRanges: strings.EqualFold(strings.TrimSpace(response.Header.Get("Accept-Ranges")), "bytes"),
		contentRange: response.Header.Get("Content-Range"),
		validator: download.ParseResourceValidator(
			response.Header.Get("ETag"),
			response.Header.Get("Last-Modified"),
		),
	}
	return probeResponse{status: response.StatusCode, metadata: metadata}, nil
}

func validateURL(rawURL string) (*url.URL, error) {
	if strings.TrimSpace(rawURL) == "" {
		return nil, fmt.Errorf("%w: URL is required", download.ErrInvalidRequest)
	}
	parsed, err := url.ParseRequestURI(rawURL)
	if err != nil || parsed.Host == "" {
		return nil, fmt.Errorf("%w: URL must be absolute", download.ErrInvalidRequest)
	}
	if parsed.Scheme != "http" && parsed.Scheme != "https" {
		return nil, fmt.Errorf("%w: %s", download.ErrUnsupportedScheme, parsed.Scheme)
	}
	return parsed, nil
}

func withRangeHeader(headers map[string]string) map[string]string {
	result := make(map[string]string, len(headers)+1)
	for name, value := range headers {
		if strings.EqualFold(name, "Range") {
			continue
		}
		result[name] = value
	}
	result["Range"] = "bytes=0-0"
	return result
}

func mergeRangeProbe(metadata *responseMetadata, probe probeResponse) error {
	if err := mergeResourceValidator(&metadata.validator, probe.metadata.validator); err != nil {
		return err
	}
	if probe.metadata.finalURL != nil {
		metadata.finalURL = probe.metadata.finalURL
	}
	if probe.metadata.fileName != "" {
		metadata.fileName = probe.metadata.fileName
	}
	if probe.metadata.contentType != "" {
		metadata.contentType = probe.metadata.contentType
	}

	switch probe.status {
	case nethttp.StatusPartialContent:
		total, valid := parseContentRangeTotal(probe.metadata.contentRange)
		if valid {
			metadata.size = total
			metadata.acceptRanges = true
		} else {
			metadata.acceptRanges = false
		}
	case nethttp.StatusOK:
		metadata.size = probe.metadata.size
		metadata.acceptRanges = false
	case nethttp.StatusRequestedRangeNotSatisfiable:
		total, valid := parseUnsatisfiedContentRangeTotal(probe.metadata.contentRange)
		if !valid {
			return fmt.Errorf("probe download with Range: unexpected HTTP status %d", probe.status)
		}
		metadata.size = total
		metadata.acceptRanges = false
	default:
		if probe.status < 200 || probe.status >= 300 {
			return fmt.Errorf("probe download with Range: unexpected HTTP status %d", probe.status)
		}
		metadata.size = probe.metadata.size
		metadata.acceptRanges = false
	}
	return nil
}

func mergeResourceValidator(current *download.ResourceValidator, observed download.ResourceValidator) error {
	if current.ETag != "" && observed.ETag != "" && current.ETag != observed.ETag {
		return fmt.Errorf("%w: ETag changed during metadata inspection", download.ErrRemoteChanged)
	}
	if current.LastModified != "" && observed.LastModified != "" && current.LastModified != observed.LastModified {
		return fmt.Errorf("%w: Last-Modified changed during metadata inspection", download.ErrRemoteChanged)
	}
	if current.ETag == "" {
		current.ETag = observed.ETag
	}
	if current.LastModified == "" {
		current.LastModified = observed.LastModified
	}
	return nil
}

func parseContentRangeTotal(value string) (int64, bool) {
	unitAndRange := strings.Fields(value)
	if len(unitAndRange) != 2 || !strings.EqualFold(unitAndRange[0], "bytes") {
		return 0, false
	}
	parts := strings.Split(unitAndRange[1], "/")
	if len(parts) != 2 || parts[0] != "0-0" || parts[1] == "*" {
		return 0, false
	}
	total, err := strconv.ParseInt(parts[1], 10, 64)
	return total, err == nil && total > 0
}

func parseUnsatisfiedContentRangeTotal(value string) (int64, bool) {
	unitAndRange := strings.Fields(value)
	if len(unitAndRange) != 2 || !strings.EqualFold(unitAndRange[0], "bytes") {
		return 0, false
	}
	parts := strings.Split(unitAndRange[1], "/")
	if len(parts) != 2 || parts[0] != "*" {
		return 0, false
	}
	total, err := strconv.ParseInt(parts[1], 10, 64)
	return total, err == nil && total >= 0
}

func fileNameFromDisposition(value string) string {
	if value == "" {
		return ""
	}
	_, parameters, err := mime.ParseMediaType(value)
	if err != nil {
		return ""
	}
	return parameters["filename"]
}

func fileNameFromURL(value *url.URL) string {
	if value == nil {
		return ""
	}
	name, err := url.PathUnescape(path.Base(value.EscapedPath()))
	if err != nil || name == "." || name == "/" {
		return ""
	}
	return download.SafeFileName(name)
}

var _ download.Resolver = (*Resolver)(nil)
