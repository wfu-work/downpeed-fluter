package bt

import (
	"bytes"
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/anacrolix/torrent/bencode"
	"github.com/anacrolix/torrent/metainfo"

	"github.com/wfu-work/downpeed-fluter/backend/internal/download"
)

func TestDownloaderPrepareValidatesSelectionAndExplicitPeers(t *testing.T) {
	directory := t.TempDir()
	metadata := testTorrentBytes(t)
	request, err := NewDownloader().Prepare(context.Background(), download.CreateBTTaskRequest{
		Metadata: metadata, SaveDirectory: directory,
		SelectedFileIndexes: []int{1}, ExplicitPeers: []string{"8.8.8.8:6881", "8.8.8.8:6881"},
	})
	if err != nil {
		t.Fatal(err)
	}
	if request.Name != "archive" || request.Total != 5 || len(request.SelectedFileIndexes) != 1 || len(request.ExplicitPeers) != 1 {
		t.Fatalf("prepared request = %#v", request)
	}
	if request.Policy != download.DefaultBTPolicySettings() {
		t.Fatalf("prepared policy = %#v", request.Policy)
	}
	if _, err = NewDownloader().Prepare(context.Background(), download.CreateBTTaskRequest{
		Metadata: metadata, SaveDirectory: directory,
		SelectedFileIndexes: []int{0}, ExplicitPeers: []string{"127.0.0.1:6881"},
	}); !errors.Is(err, download.ErrBTPeerInvalid) {
		t.Fatalf("restricted peer error = %v", err)
	}
}

func TestDownloaderPrepareSnapshotsCurrentBTPolicy(t *testing.T) {
	directory := t.TempDir()
	settings, err := download.NewSettingsManager(context.Background(), nil, directory)
	if err != nil {
		t.Fatal(err)
	}
	policy := download.DefaultBTPolicySettings()
	policy.MaxPeerConnections = 24
	if _, err = settings.UpdateSettings(context.Background(), download.EngineSettings{
		DefaultDownloadDirectory: directory,
		FileConflictPolicy:       download.DefaultFileConflictPolicy,
		Scheduler:                download.DefaultSchedulerSettings(),
		BitTorrent:               policy,
	}); err != nil {
		t.Fatal(err)
	}
	request, err := NewDownloader(settings).Prepare(context.Background(), download.CreateBTTaskRequest{
		Metadata: testTorrentBytes(t), SaveDirectory: directory,
		SelectedFileIndexes: []int{0}, ExplicitPeers: []string{"8.8.8.8:6881"},
	})
	if err != nil {
		t.Fatal(err)
	}
	if request.Policy.MaxPeerConnections != 24 || !request.Policy.ExplicitPeersOnly {
		t.Fatalf("prepared policy = %#v", request.Policy)
	}
}

func TestValidateExplicitPeersEnforcesBoundsAndNormalizesMappedIPv4(t *testing.T) {
	peers, err := validateExplicitPeers([]string{"[::ffff:8.8.8.8]:6881", "8.8.8.8:6881"})
	if err != nil || len(peers) != 1 || peers[0] != "8.8.8.8:6881" {
		t.Fatalf("normalized peers = %#v, error = %v", peers, err)
	}
	if _, err = validateExplicitPeers([]string{"[::ffff:127.0.0.1]:6881"}); !errors.Is(err, download.ErrBTPeerInvalid) {
		t.Fatalf("mapped loopback error = %v", err)
	}
	tooMany := strings.Split(strings.Repeat("8.8.8.8:6881,", maxExplicitPeers+1), ",")
	tooMany = tooMany[:len(tooMany)-1]
	if _, err = validateExplicitPeers(tooMany); !errors.Is(err, download.ErrBTPeerInvalid) {
		t.Fatalf("peer limit error = %v", err)
	}
}

func TestMaskPeerAddressRetainsOnlyNetworkPrefixAndPort(t *testing.T) {
	if got := maskPeerAddress("203.10.42.99:6881"); got != "203.10.x.x:6881" {
		t.Fatalf("masked address = %q", got)
	}
	for _, value := range []string{"203.10.42.99", "[2001:db8::1]:6881", "credentials"} {
		if got := maskPeerAddress(value); got != "Hidden" {
			t.Fatalf("masked invalid address %q = %q", value, got)
		}
	}
}

func TestPublishSelectedFilesNeverPublishesUnselectedData(t *testing.T) {
	directory := t.TempDir()
	request := download.BTTransferRequest{
		SaveDirectory: directory, Name: "archive", Identity: "abc",
		SelectedFileIndexes: []int{1},
		Files: []download.BTFile{
			{Index: 0, Path: "archive/skip.bin", Size: 4},
			{Index: 1, Path: "archive/keep.bin", Size: 5},
		},
	}
	staging := stagingDirectory(request)
	if err := os.MkdirAll(filepath.Join(staging, "archive"), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(staging, "archive", "skip.bin"), []byte("skip"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(staging, "archive", "keep.bin"), []byte("keep!"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := publishSelectedFiles(request, staging); err != nil {
		t.Fatal(err)
	}
	if data, err := os.ReadFile(filepath.Join(directory, "archive", "keep.bin")); err != nil || string(data) != "keep!" {
		t.Fatalf("selected file = %q, error = %v", data, err)
	}
	if _, err := os.Stat(filepath.Join(directory, "archive", "skip.bin")); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("unselected file was published: %v", err)
	}
	if _, err := os.Stat(staging); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("staging directory remains: %v", err)
	}
}

func TestPublishSelectedFilesRejectsReplacedStagingDirectory(t *testing.T) {
	directory := t.TempDir()
	outside := t.TempDir()
	request := download.BTTransferRequest{
		SaveDirectory: directory, Name: "archive.bin", Identity: "abc",
		SelectedFileIndexes: []int{0},
		Files:               []download.BTFile{{Index: 0, Path: "archive.bin", Size: 5}},
	}
	staging := stagingDirectory(request)
	if err := os.Symlink(outside, staging); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(outside, "archive.bin"), []byte("evil!"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := publishSelectedFiles(request, staging); !errors.Is(err, download.ErrFileConsistency) {
		t.Fatalf("publish error = %v, want ErrFileConsistency", err)
	}
	if _, err := os.Stat(filepath.Join(directory, "archive.bin")); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("replaced staging data was published: %v", err)
	}
}

func testTorrentBytes(t *testing.T) []byte {
	t.Helper()
	info := metainfo.Info{
		PieceLength: 16 * 1024, Pieces: bytes.Repeat([]byte{1}, 20), Name: "archive",
		Files: []metainfo.FileInfo{{Path: []string{"one.bin"}, Length: 3}, {Path: []string{"two.bin"}, Length: 5}},
	}
	infoBytes, err := bencode.Marshal(info)
	if err != nil {
		t.Fatal(err)
	}
	var encoded bytes.Buffer
	if err = bencode.NewEncoder(&encoded).Encode(metainfo.MetaInfo{InfoBytes: infoBytes}); err != nil {
		t.Fatal(err)
	}
	return encoded.Bytes()
}
