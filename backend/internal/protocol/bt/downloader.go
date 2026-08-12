package bt

import (
	"context"
	"errors"
	"fmt"
	"math"
	"net"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/anacrolix/torrent"

	"github.com/wfu-work/downpeed-fluter/backend/internal/download"
)

const (
	maxExplicitPeers = 80
	progressInterval = 250 * time.Millisecond
)

type Downloader struct {
	settings download.SettingsService
}

func NewDownloader(settings ...download.SettingsService) *Downloader {
	downloader := &Downloader{}
	if len(settings) > 0 {
		downloader.settings = settings[0]
	}
	return downloader
}

func (d *Downloader) Prepare(ctx context.Context, input download.CreateBTTaskRequest) (download.BTTransferRequest, error) {
	resolution, err := NewResolver().ResolveTorrent(ctx, input.Metadata)
	if err != nil {
		return download.BTTransferRequest{}, err
	}
	directory := filepath.Clean(strings.TrimSpace(input.SaveDirectory))
	if !filepath.IsAbs(directory) {
		return download.BTTransferRequest{}, download.ErrInvalidDestination
	}
	info, err := os.Stat(directory)
	if err != nil || !info.IsDir() {
		return download.BTTransferRequest{}, download.ErrInvalidDestination
	}
	selected, selectedTotal, err := validateSelection(resolution.Files, input.SelectedFileIndexes)
	if err != nil {
		return download.BTTransferRequest{}, err
	}
	peers, err := validateExplicitPeers(input.ExplicitPeers)
	if err != nil {
		return download.BTTransferRequest{}, err
	}
	identity := resolution.InfoHash
	if identity == "" {
		identity = resolution.V2InfoHash
	}
	policy := download.DefaultBTPolicySettings()
	if d.settings != nil {
		settings, settingsErr := d.settings.GetSettings(ctx)
		if settingsErr != nil {
			return download.BTTransferRequest{}, settingsErr
		}
		policy = settings.BitTorrent
	}
	return download.BTTransferRequest{
		Metadata:            append([]byte(nil), input.Metadata...),
		SaveDirectory:       directory,
		Name:                resolution.Name,
		Identity:            identity,
		Total:               selectedTotal,
		SelectedFileIndexes: selected,
		ExplicitPeers:       peers,
		Files:               append([]download.BTFile(nil), resolution.Files...),
		Policy:              policy,
	}, nil
}

func (*Downloader) Download(ctx context.Context, request download.BTTransferRequest, onProgress func(download.BTTransferProgress)) (download.BTTransferResult, error) {
	staging := stagingDirectory(request)
	if err := os.MkdirAll(staging, 0o700); err != nil {
		return download.BTTransferResult{}, download.ErrInvalidDestination
	}
	config, err := SecureClientConfig(staging, request.Policy)
	if err != nil {
		return download.BTTransferResult{}, err
	}
	client, err := torrent.NewClient(config)
	if err != nil {
		return download.BTTransferResult{}, errors.New("restricted BT client could not start")
	}
	defer client.Close()

	spec, err := RestrictedTorrentSpec(ctx, request.Metadata)
	if err != nil {
		return download.BTTransferResult{}, err
	}
	torrentTask, _, err := client.AddTorrentSpec(spec)
	if err != nil {
		return download.BTTransferResult{}, errors.New("BT metadata could not be added to the restricted client")
	}
	defer torrentTask.Drop()
	torrentTask.DisallowDataUpload()

	select {
	case <-ctx.Done():
		return download.BTTransferResult{}, ctx.Err()
	case <-torrentTask.GotInfo():
	}
	files := torrentTask.Files()
	selected := make(map[int]struct{}, len(request.SelectedFileIndexes))
	for _, index := range request.SelectedFileIndexes {
		if index < 0 || index >= len(files) {
			return download.BTTransferResult{}, download.ErrBTFileSelection
		}
		selected[index] = struct{}{}
	}
	for index, file := range files {
		if _, wanted := selected[index]; wanted {
			file.Download()
		} else {
			file.SetPriority(torrent.PiecePriorityNone)
		}
	}
	peerInfos := make([]torrent.PeerInfo, 0, len(request.ExplicitPeers))
	for _, address := range request.ExplicitPeers {
		peerInfos = append(peerInfos, torrent.PeerInfo{
			Addr:    torrent.StringAddr(address),
			Source:  torrent.PeerSourceDirect,
			Trusted: false,
		})
	}
	if torrentTask.AddPeers(peerInfos) == 0 {
		return download.BTTransferResult{}, download.ErrBTPeerRequired
	}

	ticker := time.NewTicker(progressInterval)
	defer ticker.Stop()
	lastDownloaded := selectedBytesCompleted(files, selected)
	lastAt := time.Now()
	report := func() bool {
		now := time.Now()
		downloaded := selectedBytesCompleted(files, selected)
		elapsed := now.Sub(lastAt).Seconds()
		var speed int64
		if elapsed > 0 && downloaded >= lastDownloaded {
			speed = int64(float64(downloaded-lastDownloaded) / elapsed)
		}
		stats := torrentTask.Stats()
		onProgress(download.BTTransferProgress{
			Downloaded: downloaded, Total: request.Total, SpeedBPS: speed,
			Connections: stats.ActivePeers,
			Diagnostics: buildDiagnostics(torrentTask, request, stats, now),
		})
		lastDownloaded, lastAt = downloaded, now
		return selectedFilesComplete(files, selected)
	}
	for {
		if report() {
			break
		}
		select {
		case <-ctx.Done():
			return download.BTTransferResult{}, ctx.Err()
		case <-ticker.C:
		}
	}
	if err = publishSelectedFiles(request, staging); err != nil {
		return download.BTTransferResult{}, err
	}
	return download.BTTransferResult{Size: request.Total}, nil
}

func buildDiagnostics(
	task *torrent.Torrent,
	request download.BTTransferRequest,
	stats torrent.TorrentStats,
	now time.Time,
) download.BTDiagnostics {
	peers := make([]download.BTPeerDiagnostics, 0, stats.ActivePeers)
	for _, connection := range task.PeerConns() {
		peerStats := connection.Stats()
		clientName, _ := connection.PeerClientName.Load().(string)
		if strings.TrimSpace(clientName) == "" {
			clientName = "Unknown"
		}
		address := "Hidden"
		if connection.RemoteAddr != nil {
			address = maskPeerAddress(connection.RemoteAddr.String())
		}
		rate := int64(0)
		if peerStats.DownloadRate > 0 && peerStats.DownloadRate <= float64(math.MaxInt64) {
			rate = int64(peerStats.DownloadRate)
		}
		peers = append(peers, download.BTPeerDiagnostics{
			Address:         address,
			Client:          clientName,
			Network:         strings.ToUpper(connection.Network),
			ReceivedBytes:   peerStats.BytesReadUsefulData.Int64(),
			DownloadRateBPS: rate,
			VerifiedPieces:  peerStats.PiecesDirtiedGood.Int64(),
			FailedPieces:    peerStats.PiecesDirtiedBad.Int64(),
		})
	}
	sort.Slice(peers, func(left, right int) bool {
		if peers[left].Address == peers[right].Address {
			return peers[left].Client < peers[right].Client
		}
		return peers[left].Address < peers[right].Address
	})
	return download.BTDiagnostics{
		Live: true,
		Connections: download.BTConnectionDiagnostics{
			Configured: len(request.ExplicitPeers),
			Known:      stats.TotalPeers,
			Connected:  stats.ActivePeers,
			Pending:    stats.PendingPeers,
			HalfOpen:   stats.HalfOpenPeers,
			Seeders:    stats.ConnectedSeeders,
		},
		Traffic: download.BTTrafficDiagnostics{
			ReceivedBytes:  stats.PeerConns.BytesRead.Int64(),
			UsefulBytes:    stats.PeerConns.BytesReadUsefulData.Int64(),
			UploadedBytes:  stats.PeerConns.BytesWrittenData.Int64(),
			WastedChunks:   stats.PeerConns.ChunksReadWasted.Int64(),
			VerifiedPieces: stats.PeerConns.PiecesDirtiedGood.Int64(),
			FailedPieces:   stats.PeerConns.PiecesDirtiedBad.Int64(),
		},
		Peers: peers,
		Policy: download.BTPolicyDiagnostics{
			MaxPeerConnections: request.Policy.MaxPeerConnections,
			ExplicitPeersOnly:  request.Policy.ExplicitPeersOnly,
			TrackersEnabled:    request.Policy.TrackersEnabled,
			DHTEnabled:         request.Policy.DHTEnabled,
			PEXEnabled:         request.Policy.PEXEnabled,
			WebSeedsEnabled:    request.Policy.WebSeedsEnabled,
			InboundEnabled:     request.Policy.InboundEnabled,
			IPv6Enabled:        request.Policy.IPv6Enabled,
			UploadEnabled:      request.Policy.UploadEnabled,
			SeedingEnabled:     request.Policy.SeedingEnabled,
		},
		UpdatedAt: now.UTC(),
	}
}

func maskPeerAddress(value string) string {
	host, port, err := net.SplitHostPort(value)
	if err != nil {
		return "Hidden"
	}
	ip := net.ParseIP(host).To4()
	if ip == nil {
		return "Hidden"
	}
	return net.JoinHostPort(fmt.Sprintf("%d.%d.x.x", ip[0], ip[1]), port)
}

func (*Downloader) Cleanup(_ context.Context, request download.BTTransferRequest) error {
	staging := stagingDirectory(request)
	if !isSafeStagingDirectory(request.SaveDirectory, staging) {
		return download.ErrInvalidDestination
	}
	if err := os.RemoveAll(staging); err != nil {
		return download.ErrInvalidDestination
	}
	return nil
}

func validateSelection(files []download.BTFile, indexes []int) ([]int, int64, error) {
	if len(indexes) == 0 || len(indexes) > len(files) {
		return nil, 0, download.ErrBTFileSelection
	}
	byIndex := make(map[int]download.BTFile, len(files))
	for _, file := range files {
		byIndex[file.Index] = file
	}
	seen := make(map[int]struct{}, len(indexes))
	selected := make([]int, 0, len(indexes))
	var total int64
	for _, index := range indexes {
		file, ok := byIndex[index]
		if !ok {
			return nil, 0, download.ErrBTFileSelection
		}
		if _, duplicate := seen[index]; duplicate {
			return nil, 0, download.ErrBTFileSelection
		}
		seen[index] = struct{}{}
		selected = append(selected, index)
		total += file.Size
	}
	sort.Ints(selected)
	return selected, total, nil
}

func validateExplicitPeers(values []string) ([]string, error) {
	if len(values) == 0 {
		return nil, download.ErrBTPeerRequired
	}
	if len(values) > maxExplicitPeers {
		return nil, download.ErrBTPeerInvalid
	}
	result := make([]string, 0, len(values))
	seen := make(map[string]struct{}, len(values))
	for _, value := range values {
		host, portText, err := net.SplitHostPort(strings.TrimSpace(value))
		if err != nil {
			return nil, download.ErrBTPeerInvalid
		}
		ip := net.ParseIP(host)
		port, portErr := strconv.ParseUint(portText, 10, 16)
		if portErr != nil || port == 0 || !IsAllowedPublicIP(ip) {
			return nil, download.ErrBTPeerInvalid
		}
		normalized := net.JoinHostPort(ip.To4().String(), strconv.FormatUint(port, 10))
		if _, duplicate := seen[normalized]; duplicate {
			continue
		}
		seen[normalized] = struct{}{}
		result = append(result, normalized)
	}
	if len(result) == 0 {
		return nil, download.ErrBTPeerRequired
	}
	return result, nil
}

func selectedBytesCompleted(files []*torrent.File, selected map[int]struct{}) int64 {
	var total int64
	for index := range selected {
		completed := files[index].BytesCompleted()
		if completed > files[index].Length() {
			completed = files[index].Length()
		}
		total += completed
	}
	return total
}

func selectedFilesComplete(files []*torrent.File, selected map[int]struct{}) bool {
	for index := range selected {
		for _, piece := range files[index].State() {
			if !piece.Ok || !piece.Complete || piece.Hashing || piece.QueuedForHash || piece.Marking {
				return false
			}
		}
	}
	return true
}

func stagingDirectory(request download.BTTransferRequest) string {
	return filepath.Join(request.SaveDirectory, ".downpeed-bt-"+request.Identity)
}

func isSafeStagingDirectory(saveDirectory, staging string) bool {
	return filepath.IsAbs(saveDirectory) &&
		filepath.Dir(staging) == filepath.Clean(saveDirectory) &&
		strings.HasPrefix(filepath.Base(staging), ".downpeed-bt-")
}

func publishSelectedFiles(request download.BTTransferRequest, staging string) error {
	selected := make(map[int]struct{}, len(request.SelectedFileIndexes))
	for _, index := range request.SelectedFileIndexes {
		selected[index] = struct{}{}
	}
	multiFile := false
	for _, file := range request.Files {
		if _, wanted := selected[file.Index]; wanted && file.Path != request.Name {
			multiFile = true
			break
		}
	}
	root, err := os.OpenRoot(request.SaveDirectory)
	if err != nil {
		return download.ErrAtomicPublish
	}
	defer root.Close()
	stagingName := filepath.Base(staging)
	if stagingName == "." || stagingName == string(os.PathSeparator) || filepath.Join(request.SaveDirectory, stagingName) != staging {
		return download.ErrBTPathUnsafe
	}
	if info, statErr := root.Lstat(stagingName); statErr != nil || !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		return download.ErrFileConsistency
	}
	if multiFile {
		if err := root.Mkdir(request.Name, 0o755); err != nil {
			if errors.Is(err, os.ErrExist) {
				return download.ErrDestinationExists
			}
			return download.ErrAtomicPublish
		}
	} else if _, err := root.Lstat(request.Name); err == nil {
		return download.ErrDestinationExists
	} else if !errors.Is(err, os.ErrNotExist) {
		return download.ErrAtomicPublish
	}
	rollback := true
	defer func() {
		if rollback {
			_ = root.RemoveAll(request.Name)
		}
	}()
	for _, file := range request.Files {
		if _, wanted := selected[file.Index]; !wanted {
			continue
		}
		relative, err := filepath.Rel(request.Name, filepath.FromSlash(file.Path))
		if err != nil || relative == "." && multiFile || relative == ".." || strings.HasPrefix(relative, ".."+string(os.PathSeparator)) {
			return download.ErrBTPathUnsafe
		}
		source := filepath.Join(stagingName, filepath.FromSlash(file.Path))
		target := request.Name
		if multiFile {
			target = filepath.Join(request.Name, relative)
			if err = root.MkdirAll(filepath.Dir(target), 0o755); err != nil {
				return download.ErrAtomicPublish
			}
		}
		info, err := root.Lstat(source)
		if err != nil || !info.Mode().IsRegular() || info.Size() != file.Size {
			return download.ErrFileConsistency
		}
		if err = root.Link(source, target); err != nil {
			if errors.Is(err, os.ErrExist) {
				return download.ErrDestinationExists
			}
			return fmt.Errorf("%w: selected BT file could not be linked", download.ErrAtomicPublish)
		}
	}
	rollback = false
	if err := root.RemoveAll(stagingName); err != nil {
		return download.ErrInvalidDestination
	}
	return nil
}

var _ download.BTTransfer = (*Downloader)(nil)
