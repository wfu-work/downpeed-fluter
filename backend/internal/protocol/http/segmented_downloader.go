package httpprotocol

import (
	"context"
	"errors"
	"fmt"
	"io"
	nethttp "net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/wfu-work/downpeed-fluter/backend/internal/download"
)

const (
	segmentedConnectionCount = 4
	segmentedTransferMinSize = download.DefaultSegmentedTransferMinSize
)

type segmentResult struct {
	finalURL string
	err      error
}

func (d *Downloader) downloadSegmented(
	ctx context.Context,
	input download.TransferRequest,
	parsedURL *url.URL,
	onProgress func(download.TransferProgress),
) (result download.TransferResult, returnedErr error) {
	if input.Validator.IfRangeValue() == "" {
		return download.TransferResult{}, fmt.Errorf("%w: segmented transfer requires an If-Range validator", download.ErrResumeNotSupported)
	}
	checkpoint := download.CloneTransferCheckpoint(input.Checkpoint)
	isResume := checkpoint != nil
	if checkpoint == nil {
		if input.ExpectedSize < segmentedTransferMinSize {
			return download.TransferResult{}, fmt.Errorf("%w: segmented transfer size is unavailable", download.ErrInvalidRequest)
		}
		checkpoint = newTransferCheckpoint(input.ExpectedSize, segmentedConnectionCount)
	}
	initialDownloaded, err := download.ValidateTransferCheckpoint(checkpoint, input.ExpectedSize)
	if err != nil || initialDownloaded != input.Offset {
		return download.TransferResult{}, download.ErrPartialFileChanged
	}

	var file *os.File
	if isResume {
		info, statErr := os.Lstat(input.WorkPath)
		if statErr != nil || !info.Mode().IsRegular() || info.Size() != checkpoint.Total {
			return download.TransferResult{}, download.ErrPartialFileChanged
		}
		file, err = os.OpenFile(input.WorkPath, os.O_RDWR, 0o644)
	} else {
		file, err = os.OpenFile(input.WorkPath, os.O_RDWR|os.O_CREATE|os.O_EXCL, 0o644)
		if errors.Is(err, os.ErrExist) {
			return download.TransferResult{}, download.ErrDestinationExists
		}
		if err == nil {
			err = file.Truncate(checkpoint.Total)
		}
	}
	if err != nil || file == nil {
		if file != nil {
			_ = file.Close()
			_ = os.Remove(input.WorkPath)
		}
		return download.TransferResult{}, fmt.Errorf("%w: open segmented destination", download.ErrInvalidDestination)
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
			// A persisted checkpoint makes the preallocated work file resumable.
		default:
			_ = os.Remove(input.WorkPath)
		}
	}()

	startedAt := time.Now()
	lastReport := startedAt
	var progressMu sync.Mutex
	reportProgress := func(segmentIndex int, count int64, force bool) {
		progressMu.Lock()
		if segmentIndex >= 0 {
			checkpoint.Segments[segmentIndex].Completed += count
		}
		now := time.Now()
		if onProgress == nil || (!force && now.Sub(lastReport) < progressReportInterval) {
			progressMu.Unlock()
			return
		}
		downloaded, checkpointErr := download.ValidateTransferCheckpoint(checkpoint, checkpoint.Total)
		if checkpointErr != nil {
			progressMu.Unlock()
			return
		}
		elapsed := now.Sub(startedAt).Seconds()
		speed := int64(0)
		if elapsed > 0 {
			speed = int64(float64(downloaded-initialDownloaded) / elapsed)
		}
		progress := download.TransferProgress{
			Downloaded: downloaded,
			Total:      checkpoint.Total,
			SpeedBPS:   speed,
			Checkpoint: download.CloneTransferCheckpoint(checkpoint),
		}
		lastReport = now
		progressMu.Unlock()
		onProgress(progress)
	}
	reportProgress(-1, 0, true)

	workerCtx, cancelWorkers := context.WithCancel(ctx)
	defer cancelWorkers()
	results := make(chan segmentResult, len(checkpoint.Segments))
	activeSegments := 0
	for index, segment := range checkpoint.Segments {
		segmentLength := segment.End - segment.Start + 1
		if segment.Completed == segmentLength {
			continue
		}
		activeSegments++
		go func(segmentIndex int, current download.SegmentProgress) {
			finalURL, transferErr := d.downloadSegment(
				workerCtx,
				input,
				parsedURL,
				file,
				current,
				checkpoint.Total,
				func(count int64) { reportProgress(segmentIndex, count, false) },
			)
			results <- segmentResult{finalURL: finalURL, err: transferErr}
		}(index, segment)
	}

	firstErr := error(nil)
	finalURL := ""
	for range activeSegments {
		segment := <-results
		if segment.err != nil && firstErr == nil {
			firstErr = segment.err
			cancelWorkers()
		}
		if segment.err == nil {
			if finalURL == "" {
				finalURL = segment.finalURL
			} else if finalURL != segment.finalURL && firstErr == nil {
				firstErr = fmt.Errorf("%w: segmented requests resolved to different URLs", download.ErrResumeNotSupported)
				cancelWorkers()
			}
		}
	}
	reportProgress(-1, 0, true)
	if ctx.Err() != nil {
		return download.TransferResult{}, ctx.Err()
	}
	if firstErr != nil {
		return download.TransferResult{}, firstErr
	}

	downloaded, err := download.ValidateTransferCheckpoint(checkpoint, checkpoint.Total)
	if err != nil || downloaded != checkpoint.Total {
		return download.TransferResult{}, fmt.Errorf("%w: segmented transfer is incomplete", download.ErrPartialFileChanged)
	}
	info, err := file.Stat()
	if err != nil || !info.Mode().IsRegular() || info.Size() != checkpoint.Total {
		return download.TransferResult{}, download.ErrPartialFileChanged
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
	if finalURL == "" {
		finalURL = parsedURL.String()
	}
	return download.TransferResult{FinalURL: finalURL, Size: checkpoint.Total}, nil
}

func (d *Downloader) downloadSegment(
	ctx context.Context,
	input download.TransferRequest,
	parsedURL *url.URL,
	file *os.File,
	segment download.SegmentProgress,
	total int64,
	onWrite func(int64),
) (string, error) {
	start := segment.Start + segment.Completed
	remaining := segment.End - start + 1
	request, err := nethttp.NewRequestWithContext(ctx, nethttp.MethodGet, parsedURL.String(), nil)
	if err != nil {
		return "", err
	}
	for name, value := range input.Headers {
		request.Header.Set(name, value)
	}
	request.Header.Set("Accept-Encoding", "identity")
	request.Header.Set("Range", fmt.Sprintf("bytes=%d-%d", start, segment.End))
	validatorCondition := applyResourceValidator(request, input.Validator, true)

	response, err := d.client.Do(request)
	if err != nil {
		return "", err
	}
	defer response.Body.Close()
	if isTemporaryHTTPStatus(response.StatusCode) {
		return "", fmt.Errorf("%w: segmented HTTP status %d", download.ErrRemoteTemporary, response.StatusCode)
	}
	if response.StatusCode != nethttp.StatusPartialContent {
		if validatorCondition {
			return "", fmt.Errorf("%w: segmented If-Range was not satisfied", download.ErrRemoteChanged)
		}
		return "", fmt.Errorf("%w: segmented HTTP status %d", download.ErrResumeNotSupported, response.StatusCode)
	}
	if resourceValidatorChanged(input.Validator, response.Header) {
		return "", fmt.Errorf("%w: segmented response validator mismatch", download.ErrRemoteChanged)
	}
	if encoding := strings.TrimSpace(response.Header.Get("Content-Encoding")); encoding != "" && !strings.EqualFold(encoding, "identity") {
		return "", fmt.Errorf("%w: encoded segment cannot be byte-validated", download.ErrFileConsistency)
	}
	reportedTotal, reportedLength, err := parseResumeContentRange(response.Header.Get("Content-Range"), start)
	if err != nil || reportedTotal != total || reportedLength != remaining {
		return "", fmt.Errorf("%w: Content-Range does not match requested segment", download.ErrResumeNotSupported)
	}
	if response.ContentLength >= 0 && response.ContentLength != remaining {
		return "", fmt.Errorf("%w: Content-Length does not match requested segment", download.ErrResumeNotSupported)
	}

	buffer := make([]byte, transferBufferSize)
	received := int64(0)
	for {
		count, readErr := response.Body.Read(buffer)
		if count > 0 {
			if received+int64(count) > remaining {
				return "", fmt.Errorf("%w: segment response exceeded its byte range", download.ErrResumeNotSupported)
			}
			if input.Limiter != nil {
				if err = input.Limiter.WaitN(ctx, count); err != nil {
					return "", err
				}
			}
			if err = writeAllAt(file, buffer[:count], start+received); err != nil {
				return "", err
			}
			received += int64(count)
			onWrite(int64(count))
		}
		if readErr != nil {
			if errors.Is(readErr, io.EOF) {
				break
			}
			return "", readErr
		}
		if err = ctx.Err(); err != nil {
			return "", err
		}
	}
	if received != remaining {
		return "", io.ErrUnexpectedEOF
	}
	finalURL := parsedURL.String()
	if response.Request != nil && response.Request.URL != nil {
		finalURL = response.Request.URL.String()
	}
	return finalURL, nil
}

func newTransferCheckpoint(total int64, connectionCount int) *download.TransferCheckpoint {
	checkpoint := &download.TransferCheckpoint{
		Version: download.TransferCheckpointVersion,
		Total:   total,
	}
	baseLength := total / int64(connectionCount)
	remainder := total % int64(connectionCount)
	start := int64(0)
	for index := 0; index < connectionCount; index++ {
		length := baseLength
		if int64(index) < remainder {
			length++
		}
		checkpoint.Segments = append(checkpoint.Segments, download.SegmentProgress{
			Start: start,
			End:   start + length - 1,
		})
		start += length
	}
	return checkpoint
}

func writeAllAt(file *os.File, value []byte, offset int64) error {
	for len(value) > 0 {
		count, err := file.WriteAt(value, offset)
		if err != nil {
			return err
		}
		if count == 0 {
			return io.ErrShortWrite
		}
		offset += int64(count)
		value = value[count:]
	}
	return nil
}
