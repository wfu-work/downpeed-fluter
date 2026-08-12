package bt

import (
	"bytes"
	"context"

	"github.com/anacrolix/torrent"
	"github.com/anacrolix/torrent/metainfo"
)

// RestrictedMagnetSpec retains only the torrent identity. Trackers, webseeds,
// metainfo sources, DHT nodes, and embedded peers never cross into the client.
func RestrictedMagnetSpec(ctx context.Context, raw string) (*torrent.TorrentSpec, error) {
	if _, err := NewResolver().ResolveMagnet(ctx, raw); err != nil {
		return nil, err
	}
	spec, err := torrent.TorrentSpecFromMagnetUri(raw)
	if err != nil {
		return nil, err
	}
	restrictSpec(spec)
	return spec, nil
}

// RestrictedTorrentSpec repeats Downpeed's bounded metadata validation before
// translating metadata into an upstream client spec.
func RestrictedTorrentSpec(ctx context.Context, data []byte) (*torrent.TorrentSpec, error) {
	if _, err := NewResolver().ResolveTorrent(ctx, data); err != nil {
		return nil, err
	}
	metadata, err := metainfo.Load(bytes.NewReader(data))
	if err != nil {
		return nil, err
	}
	spec, err := torrent.TorrentSpecFromMetaInfoErr(metadata)
	if err != nil {
		return nil, err
	}
	restrictSpec(spec)
	return spec, nil
}

func restrictSpec(spec *torrent.TorrentSpec) {
	spec.Trackers = nil
	spec.Webseeds = nil
	spec.DhtNodes = nil
	spec.PeerAddrs = nil
	spec.Sources = nil
	spec.DisallowDataUpload = true
	spec.DisableInitialPieceCheck = false
}
