package httpprotocol

import (
	"context"
	"errors"
	"fmt"
	"io"
	nethttp "net/http"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/wfu-work/downpeed-fluter/backend/internal/download"
)

const (
	transferBufferSize     = 64 * 1024
	progressReportInterval = 100 * time.Millisecond
)

type Downloader struct {
	client *nethttp.Client
}

func NewDownloader(client *nethttp.Client) *Downloader {
	if client == nil {
		client = &nethttp.Client{}
	}
	return &Downloader{client: client}
}

func (d *Downloader) Download(
	ctx context.Context,
	input download.TransferRequest,
	onProgress func(download.TransferProgress),
) (result download.TransferResult, returnedErr error) {
	parsedURL, err := url.ParseRequestURI(input.URL)
	if err != nil || parsedURL.Host == "" || (parsedURL.Scheme != "http" && parsedURL.Scheme != "https") {
		return download.TransferResult{}, fmt.Errorf("%w: invalid HTTP download URL", download.ErrInvalidRequest)
	}
	if !filepath.IsAbs(input.Destination) {
		return download.TransferResult{}, fmt.Errorf("%w: destination must be absolute", download.ErrInvalidDestination)
	}
	if !filepath.IsAbs(input.WorkPath) || filepath.Dir(input.WorkPath) != filepath.Dir(input.Destination) || input.WorkPath == input.Destination {
		return download.TransferResult{}, fmt.Errorf("%w: temporary file must share the destination directory", download.ErrInvalidDestination)
	}
	directoryInfo, err := os.Stat(filepath.Dir(input.Destination))
	if err != nil || !directoryInfo.IsDir() {
		return download.TransferResult{}, fmt.Errorf("%w: destination directory is unavailable", download.ErrInvalidDestination)
	}
	if input.Offset < 0 {
		return download.TransferResult{}, fmt.Errorf("%w: resume offset cannot be negative", download.ErrInvalidRequest)
	}
	if input.ExpectedSize > 0 && input.Offset > input.ExpectedSize {
		return download.TransferResult{}, download.ErrPartialFileChanged
	}
	if _, err = os.Lstat(input.Destination); err == nil {
		return download.TransferResult{}, download.ErrDestinationExists
	} else if !errors.Is(err, os.ErrNotExist) {
		return download.TransferResult{}, fmt.Errorf("%w: destination cannot be checked", download.ErrInvalidDestination)
	}
	if input.Checkpoint != nil || (input.AllowSegments && input.ExpectedSize >= segmentedTransferMinSize) {
		return d.downloadSegmented(ctx, input, parsedURL, onProgress)
	}

	var file *os.File
	if input.Offset == 0 {
		file, err = os.OpenFile(input.WorkPath, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o644)
		if errors.Is(err, os.ErrExist) {
			return download.TransferResult{}, download.ErrDestinationExists
		}
	} else {
		var info os.FileInfo
		info, err = os.Lstat(input.WorkPath)
		if err == nil && (!info.Mode().IsRegular() || info.Size() != input.Offset) {
			return download.TransferResult{}, download.ErrPartialFileChanged
		}
		if err == nil {
			file, err = os.OpenFile(input.WorkPath, os.O_WRONLY|os.O_APPEND, 0o644)
		}
	}
	if err != nil || file == nil {
		return download.TransferResult{}, fmt.Errorf("%w: open destination", download.ErrInvalidDestination)
	}
	complete := false
	defer func() {
		_ = file.Close()
		if complete {
			return
		}
		switch {
		case errors.Is(context.Cause(ctx), download.ErrTransferPaused),
			errors.Is(context.Cause(ctx), download.ErrTransferShutdown):
			// Pausing and graceful shutdown intentionally keep completed bytes.
		case errors.Is(context.Cause(ctx), download.ErrTransferCanceled):
			_ = os.Remove(input.WorkPath)
		case input.Offset > 0:
			// A failed resume rolls back newly appended bytes to the verified offset.
			_ = os.Truncate(input.WorkPath, input.Offset)
		default:
			_ = os.Remove(input.WorkPath)
		}
	}()
	if input.ExpectedSize > 0 && input.Offset == input.ExpectedSize {
		if err = file.Sync(); err != nil {
			return download.TransferResult{}, err
		}
		if err = file.Close(); err != nil {
			return download.TransferResult{}, err
		}
		if err = publishCompletedFile(input.WorkPath, input.Destination); err != nil {
			return download.TransferResult{}, err
		}
		complete = true
		return download.TransferResult{FinalURL: parsedURL.String(), Size: input.Offset}, nil
	}

	request, err := nethttp.NewRequestWithContext(ctx, nethttp.MethodGet, parsedURL.String(), nil)
	if err != nil {
		return download.TransferResult{}, err
	}
	for name, value := range input.Headers {
		request.Header.Set(name, value)
	}
	request.Header.Set("Accept-Encoding", "identity")
	if input.Offset > 0 {
		request.Header.Set("Range", fmt.Sprintf("bytes=%d-", input.Offset))
	}
	validatorCondition := applyResourceValidator(request, input.Validator, input.Offset > 0)

	response, err := d.client.Do(request)
	if err != nil {
		return download.TransferResult{}, err
	}
	defer response.Body.Close()
	if isTemporaryHTTPStatus(response.StatusCode) {
		return download.TransferResult{}, fmt.Errorf("%w: HTTP status %d", download.ErrRemoteTemporary, response.StatusCode)
	}
	if response.StatusCode == nethttp.StatusPreconditionFailed && validatorCondition {
		return download.TransferResult{}, fmt.Errorf("%w: HTTP precondition failed", download.ErrRemoteChanged)
	}
	if input.Offset > 0 && response.StatusCode != nethttp.StatusPartialContent {
		if validatorCondition {
			return download.TransferResult{}, fmt.Errorf(
				"%w: If-Range was not satisfied",
				download.ErrRemoteChanged,
			)
		}
		return download.TransferResult{}, fmt.Errorf(
			"%w: HTTP status %d",
			download.ErrResumeNotSupported,
			response.StatusCode,
		)
	}
	if input.Offset == 0 && (response.StatusCode < 200 || response.StatusCode >= 300) {
		return download.TransferResult{}, fmt.Errorf("%w: HTTP status %d", download.ErrRemoteRejected, response.StatusCode)
	}
	if resourceValidatorChanged(input.Validator, response.Header) {
		return download.TransferResult{}, fmt.Errorf("%w: response validator mismatch", download.ErrRemoteChanged)
	}
	if encoding := strings.TrimSpace(response.Header.Get("Content-Encoding")); encoding != "" && !strings.EqualFold(encoding, "identity") {
		return download.TransferResult{}, fmt.Errorf("%w: encoded response cannot be byte-validated", download.ErrFileConsistency)
	}

	total := response.ContentLength
	if input.Offset > 0 {
		var rangeLength int64
		total, rangeLength, err = parseResumeContentRange(response.Header.Get("Content-Range"), input.Offset)
		if err != nil {
			return download.TransferResult{}, err
		}
		if response.ContentLength >= 0 && response.ContentLength != rangeLength {
			return download.TransferResult{}, fmt.Errorf(
				"%w: Content-Length does not match Content-Range",
				download.ErrResumeNotSupported,
			)
		}
	}
	if input.ExpectedSize > 0 && total >= 0 && total != input.ExpectedSize {
		return download.TransferResult{}, fmt.Errorf("%w: remote size changed", download.ErrFileConsistency)
	}
	startedAt := time.Now()
	lastReport := startedAt
	downloaded := input.Offset
	report := func(now time.Time) {
		if onProgress == nil {
			return
		}
		elapsed := now.Sub(startedAt).Seconds()
		speed := int64(0)
		if elapsed > 0 {
			speed = int64(float64(downloaded-input.Offset) / elapsed)
		}
		onProgress(download.TransferProgress{
			Downloaded: downloaded,
			Total:      total,
			SpeedBPS:   speed,
		})
	}
	report(startedAt)

	buffer := make([]byte, transferBufferSize)
	for {
		count, readErr := response.Body.Read(buffer)
		if count > 0 {
			if input.Limiter != nil {
				if err = input.Limiter.WaitN(ctx, count); err != nil {
					return download.TransferResult{}, err
				}
			}
			if err = writeAll(file, buffer[:count]); err != nil {
				return download.TransferResult{}, err
			}
			downloaded += int64(count)
			now := time.Now()
			if now.Sub(lastReport) >= progressReportInterval {
				report(now)
				lastReport = now
			}
		}
		if readErr != nil {
			if errors.Is(readErr, io.EOF) {
				break
			}
			return download.TransferResult{}, readErr
		}
		if err = ctx.Err(); err != nil {
			return download.TransferResult{}, err
		}
	}
	report(time.Now())
	if (total >= 0 && downloaded != total) || (input.ExpectedSize > 0 && downloaded != input.ExpectedSize) {
		return download.TransferResult{}, fmt.Errorf("%w: response body size changed", download.ErrFileConsistency)
	}
	if err = file.Sync(); err != nil {
		return download.TransferResult{}, err
	}
	if err = file.Close(); err != nil {
		return download.TransferResult{}, err
	}
	if err = publishCompletedFile(input.WorkPath, input.Destination); err != nil {
		return download.TransferResult{}, err
	}
	complete = true

	finalURL := parsedURL.String()
	if response.Request != nil && response.Request.URL != nil {
		finalURL = response.Request.URL.String()
	}
	return download.TransferResult{FinalURL: finalURL, Size: downloaded}, nil
}

func publishCompletedFile(workPath, destination string) error {
	if _, err := os.Lstat(destination); err == nil {
		return download.ErrDestinationExists
	} else if !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("%w: destination cannot be checked", download.ErrInvalidDestination)
	}
	if err := os.Link(workPath, destination); err != nil {
		if errors.Is(err, os.ErrExist) {
			return download.ErrDestinationExists
		}
		return fmt.Errorf("%w: %v", download.ErrAtomicPublish, err)
	}
	// The final path now points at the fully synced inode. Removing the work
	// name is cleanup only; failure here does not make the completed file unsafe.
	_ = os.Remove(workPath)
	return nil
}

func parseResumeContentRange(value string, offset int64) (total int64, length int64, err error) {
	unit, spec, found := strings.Cut(strings.TrimSpace(value), " ")
	if !found || strings.ToLower(unit) != "bytes" {
		return 0, 0, fmt.Errorf("%w: missing byte Content-Range", download.ErrResumeNotSupported)
	}
	byteRange, totalValue, found := strings.Cut(strings.TrimSpace(spec), "/")
	if !found {
		return 0, 0, fmt.Errorf("%w: malformed Content-Range", download.ErrResumeNotSupported)
	}
	startValue, endValue, found := strings.Cut(byteRange, "-")
	if !found {
		return 0, 0, fmt.Errorf("%w: malformed byte range", download.ErrResumeNotSupported)
	}
	start, startErr := strconv.ParseInt(startValue, 10, 64)
	end, endErr := strconv.ParseInt(endValue, 10, 64)
	if startErr != nil || endErr != nil || start != offset || end < start {
		return 0, 0, fmt.Errorf("%w: unexpected byte range", download.ErrResumeNotSupported)
	}
	total = -1
	if totalValue != "*" {
		total, err = strconv.ParseInt(totalValue, 10, 64)
		if err != nil || total <= end {
			return 0, 0, fmt.Errorf("%w: invalid total size", download.ErrResumeNotSupported)
		}
	}
	return total, end - start + 1, nil
}

func writeAll(writer io.Writer, value []byte) error {
	for len(value) > 0 {
		count, err := writer.Write(value)
		if err != nil {
			return err
		}
		if count == 0 {
			return io.ErrShortWrite
		}
		value = value[count:]
	}
	return nil
}

var _ download.Transfer = (*Downloader)(nil)

func isTemporaryHTTPStatus(status int) bool {
	return status == nethttp.StatusRequestTimeout || status == nethttp.StatusTooManyRequests || status >= 500
}

func applyResourceValidator(request *nethttp.Request, validator download.ResourceValidator, rangeRequest bool) bool {
	if rangeRequest {
		if value := validator.IfRangeValue(); value != "" {
			request.Header.Set("If-Range", value)
			return true
		}
		return false
	}
	if etag := validator.StrongETag(); etag != "" {
		request.Header.Set("If-Match", etag)
		return true
	}
	if validator.LastModified != "" {
		request.Header.Set("If-Unmodified-Since", validator.LastModified)
		return true
	}
	return false
}

func resourceValidatorChanged(expected download.ResourceValidator, header nethttp.Header) bool {
	observed := download.ParseResourceValidator(header.Get("ETag"), header.Get("Last-Modified"))
	if expected.StrongETag() != "" {
		return observed.ETag != "" && observed.ETag != expected.ETag
	}
	if expected.LastModified != "" {
		return observed.LastModified != "" && observed.LastModified != expected.LastModified
	}
	return expected.ETag != "" && observed.ETag != "" && observed.ETag != expected.ETag
}
