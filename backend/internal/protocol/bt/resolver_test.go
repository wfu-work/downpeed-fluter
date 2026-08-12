package bt

import (
	"bytes"
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/anacrolix/torrent/bencode"
	"github.com/anacrolix/torrent/metainfo"

	"github.com/wfu-work/downpeed-fluter/backend/internal/download"
)

func TestResolverParsesMagnetWithoutFetchingMetadata(t *testing.T) {
	resolution, err := NewResolver().ResolveMagnet(
		context.Background(),
		"magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&dn=Downpeed%20Archive&tr=https%3A%2F%2Ftracker.example.com%2Fannounce%3Fpasskey%3Dsecret",
	)
	if err != nil {
		t.Fatal(err)
	}
	if resolution.SourceType != download.BTSourceMagnet || resolution.MetadataAvailable || resolution.TotalSize != -1 {
		t.Fatalf("resolution = %#v", resolution)
	}
	if resolution.Name != "Downpeed Archive" || resolution.InfoHash != "0123456789abcdef0123456789abcdef01234567" {
		t.Fatalf("identity = %#v", resolution)
	}
	if len(resolution.Files) != 0 || len(resolution.Trackers) != 1 {
		t.Fatalf("metadata = %#v", resolution)
	}
	if tracker := resolution.Trackers[0]; tracker.Scheme != "https" || tracker.Host != "tracker.example.com" {
		t.Fatalf("safe tracker = %#v", tracker)
	}
}

func TestResolverParsesV2Magnet(t *testing.T) {
	const v2 = "magnet:?xt=urn:btmh:1220a0d0a1b2c3d4e5f60718293a4b5c6d7e8f900102030405060708090a0b0c0d0e"
	resolution, err := NewResolver().ResolveMagnet(context.Background(), v2)
	if err != nil {
		t.Fatal(err)
	}
	if resolution.V2InfoHash != "a0d0a1b2c3d4e5f60718293a4b5c6d7e8f900102030405060708090a0b0c0d0e" || resolution.InfoHash != "" {
		t.Fatalf("resolution = %#v", resolution)
	}
}

func TestResolverRejectsUnsafeMagnetInputs(t *testing.T) {
	for _, value := range []string{
		"https://example.com/file.torrent",
		"magnet:?dn=missing-hash",
		"magnet:?xt=urn:btih:not-a-hash",
		"magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&tr=file%3A%2F%2F%2Ftmp%2Ftracker",
		"magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567\n",
	} {
		if _, err := NewResolver().ResolveMagnet(context.Background(), value); err == nil {
			t.Fatalf("ResolveMagnet(%q) error = nil", value)
		}
	}
	tooLarge := "magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&dn=" + strings.Repeat("x", download.MaxMagnetURIBytes)
	if _, err := NewResolver().ResolveMagnet(context.Background(), tooLarge); !errors.Is(err, download.ErrBTInvalidMagnet) {
		t.Fatalf("oversized magnet error = %v", err)
	}
}

func TestResolverParsesTorrentAndNormalizesSafeFileTree(t *testing.T) {
	private := true
	data := torrentBytes(t, metainfo.MetaInfo{
		Announce: "https://tracker.example.com/announce?passkey=secret",
	}, metainfo.Info{
		PieceLength: 16 * 1024,
		Pieces:      bytes.Repeat([]byte{1}, 20),
		Name:        "Downpeed Archive",
		Private:     &private,
		Files: []metainfo.FileInfo{
			{Path: []string{"docs", "readme.txt"}, Length: 5},
			{Path: []string{"video.mp4"}, Length: 7},
		},
	})

	resolution, err := NewResolver().ResolveTorrent(context.Background(), data)
	if err != nil {
		t.Fatal(err)
	}
	if resolution.SourceType != download.BTSourceTorrent || !resolution.MetadataAvailable || !resolution.Private || resolution.TotalSize != 12 {
		t.Fatalf("resolution = %#v", resolution)
	}
	if len(resolution.Files) != 2 || resolution.Files[0].Path != "Downpeed Archive/docs/readme.txt" || resolution.Files[1].Path != "Downpeed Archive/video.mp4" {
		t.Fatalf("files = %#v", resolution.Files)
	}
	if resolution.InfoHash == "" || len(resolution.Trackers) != 1 || resolution.Trackers[0].Host != "tracker.example.com" {
		t.Fatalf("identity/trackers = %#v", resolution)
	}
}

func TestResolverRejectsUnsafeTorrentPathsAndSymlinks(t *testing.T) {
	for name, files := range map[string][]metainfo.FileInfo{
		"parent traversal": {{Path: []string{"..", "outside.txt"}, Length: 1}},
		"absolute segment": {{Path: []string{"/etc/passwd"}, Length: 1}},
		"windows device":   {{Path: []string{"CON"}, Length: 1}},
		"symlink":          {{Path: []string{"link"}, Length: 1, ExtendedFileAttrs: metainfo.ExtendedFileAttrs{Attr: "l", SymlinkPath: []string{"target"}}}},
	} {
		t.Run(name, func(t *testing.T) {
			data := torrentBytes(t, metainfo.MetaInfo{}, metainfo.Info{
				PieceLength: 16 * 1024,
				Pieces:      bytes.Repeat([]byte{1}, 20),
				Name:        "root",
				Files:       files,
			})
			if _, err := NewResolver().ResolveTorrent(context.Background(), data); !errors.Is(err, download.ErrBTPathUnsafe) {
				t.Fatalf("ResolveTorrent() error = %v, want ErrBTPathUnsafe", err)
			}
		})
	}
}

func TestResolverRejectsMalformedAndOversizedTorrentMetadata(t *testing.T) {
	duplicateKey := []byte("d4:info1:a4:info1:be")
	if _, err := NewResolver().ResolveTorrent(context.Background(), duplicateKey); !errors.Is(err, download.ErrBTMetadataInvalid) {
		t.Fatalf("duplicate key error = %v", err)
	}
	deep := []byte(strings.Repeat("l", maxBencodeDepth+2) + strings.Repeat("e", maxBencodeDepth+2))
	if _, err := NewResolver().ResolveTorrent(context.Background(), deep); !errors.Is(err, download.ErrBTMetadataInvalid) {
		t.Fatalf("recursive metadata error = %v", err)
	}
	tooLarge := make([]byte, download.MaxTorrentMetadataBytes+1)
	if _, err := NewResolver().ResolveTorrent(context.Background(), tooLarge); !errors.Is(err, download.ErrBTMetadataTooLarge) {
		t.Fatalf("oversized metadata error = %v", err)
	}
}

func TestResolverRejectsV1PieceCountMismatch(t *testing.T) {
	data := torrentBytes(t, metainfo.MetaInfo{}, metainfo.Info{
		PieceLength: 16 * 1024,
		Pieces:      bytes.Repeat([]byte{1}, 20),
		Name:        "archive.bin",
		Length:      32*1024 + 1,
	})

	if _, err := NewResolver().ResolveTorrent(context.Background(), data); !errors.Is(err, download.ErrBTMetadataInvalid) {
		t.Fatalf("ResolveTorrent() error = %v, want ErrBTMetadataInvalid", err)
	}
}

func torrentBytes(t *testing.T, metadata metainfo.MetaInfo, info metainfo.Info) []byte {
	t.Helper()
	encodedInfo, err := bencode.Marshal(info)
	if err != nil {
		t.Fatal(err)
	}
	metadata.InfoBytes = encodedInfo
	var buffer bytes.Buffer
	if err = metadata.Write(&buffer); err != nil {
		t.Fatal(err)
	}
	return buffer.Bytes()
}
