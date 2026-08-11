package download

import "fmt"

const (
	TransferCheckpointVersion       = 1
	DefaultSegmentedTransferMinSize = int64(1 << 20)
)

type TransferCheckpoint struct {
	Version  int               `json:"version"`
	Total    int64             `json:"total"`
	Segments []SegmentProgress `json:"segments"`
}

type SegmentProgress struct {
	Start     int64 `json:"start"`
	End       int64 `json:"end"`
	Completed int64 `json:"completed"`
}

func CloneTransferCheckpoint(checkpoint *TransferCheckpoint) *TransferCheckpoint {
	if checkpoint == nil {
		return nil
	}
	cloned := &TransferCheckpoint{
		Version: checkpoint.Version,
		Total:   checkpoint.Total,
	}
	cloned.Segments = append(cloned.Segments, checkpoint.Segments...)
	return cloned
}

func ValidateTransferCheckpoint(checkpoint *TransferCheckpoint, expectedTotal int64) (int64, error) {
	if checkpoint == nil || checkpoint.Version != TransferCheckpointVersion || checkpoint.Total <= 0 {
		return 0, fmt.Errorf("%w: invalid segmented transfer checkpoint", ErrPartialFileChanged)
	}
	if expectedTotal > 0 && checkpoint.Total != expectedTotal {
		return 0, fmt.Errorf("%w: segmented transfer size changed", ErrPartialFileChanged)
	}
	if len(checkpoint.Segments) == 0 || len(checkpoint.Segments) > 64 {
		return 0, fmt.Errorf("%w: invalid segmented transfer layout", ErrPartialFileChanged)
	}

	nextStart := int64(0)
	downloaded := int64(0)
	for _, segment := range checkpoint.Segments {
		if segment.Start != nextStart || segment.End < segment.Start || segment.End >= checkpoint.Total {
			return 0, fmt.Errorf("%w: invalid segmented transfer boundary", ErrPartialFileChanged)
		}
		length := segment.End - segment.Start + 1
		if segment.Completed < 0 || segment.Completed > length {
			return 0, fmt.Errorf("%w: invalid segmented transfer progress", ErrPartialFileChanged)
		}
		downloaded += segment.Completed
		nextStart = segment.End + 1
	}
	if nextStart != checkpoint.Total || downloaded > checkpoint.Total {
		return 0, fmt.Errorf("%w: incomplete segmented transfer layout", ErrPartialFileChanged)
	}
	return downloaded, nil
}
