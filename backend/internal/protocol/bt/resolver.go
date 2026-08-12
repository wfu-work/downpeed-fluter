package bt

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"net"
	"net/url"
	"strconv"
	"strings"
	"unicode"
	"unicode/utf8"

	"github.com/anacrolix/torrent/metainfo"
	"golang.org/x/text/unicode/norm"

	"github.com/wfu-work/downpeed-fluter/backend/internal/download"
)

const (
	maxBencodeDepth  = 64
	maxBencodeValues = 200_000
	maxMagnetParams  = 256
)

type Resolver struct{}

func NewResolver() *Resolver { return &Resolver{} }

func (*Resolver) ResolveMagnet(ctx context.Context, raw string) (download.BTResolution, error) {
	if err := ctx.Err(); err != nil {
		return download.BTResolution{}, err
	}
	if len(raw) == 0 || len(raw) > download.MaxMagnetURIBytes || containsControl(raw) {
		return download.BTResolution{}, download.ErrBTInvalidMagnet
	}
	parsed, err := url.Parse(raw)
	if err != nil || !strings.EqualFold(parsed.Scheme, "magnet") || parsed.Host != "" || parsed.Fragment != "" {
		return download.BTResolution{}, download.ErrBTInvalidMagnet
	}
	parameterCount := 0
	for _, values := range parsed.Query() {
		parameterCount += len(values)
		if parameterCount > maxMagnetParams {
			return download.BTResolution{}, download.ErrBTInvalidMagnet
		}
	}

	magnet, err := metainfo.ParseMagnetV2Uri(raw)
	if err != nil || (!magnet.InfoHash.Ok && !magnet.V2InfoHash.Ok) {
		return download.BTResolution{}, download.ErrBTInvalidMagnet
	}
	trackers, err := safeTrackers(magnet.Trackers)
	if err != nil {
		return download.BTResolution{}, err
	}
	name := safeDisplayName(magnet.DisplayName)
	if name == "" {
		name = "Magnet download"
	}
	resolution := download.BTResolution{
		SourceType: download.BTSourceMagnet,
		Name:       name,
		TotalSize:  -1,
		Files:      []download.BTFile{},
		Trackers:   trackers,
	}
	if magnet.InfoHash.Ok {
		resolution.InfoHash = magnet.InfoHash.Value.HexString()
	}
	if magnet.V2InfoHash.Ok {
		resolution.V2InfoHash = magnet.V2InfoHash.Value.HexString()
	}
	return resolution, nil
}

func (*Resolver) ResolveTorrent(ctx context.Context, data []byte) (download.BTResolution, error) {
	if err := ctx.Err(); err != nil {
		return download.BTResolution{}, err
	}
	if len(data) == 0 {
		return download.BTResolution{}, download.ErrBTMetadataInvalid
	}
	if len(data) > download.MaxTorrentMetadataBytes {
		return download.BTResolution{}, download.ErrBTMetadataTooLarge
	}
	if err := validateBencode(data); err != nil {
		return download.BTResolution{}, fmt.Errorf("%w: malformed bencode", download.ErrBTMetadataInvalid)
	}
	metadata, err := metainfo.Load(bytes.NewReader(data))
	if err != nil || len(metadata.InfoBytes) == 0 {
		return download.BTResolution{}, fmt.Errorf("%w: metainfo cannot be decoded", download.ErrBTMetadataInvalid)
	}
	info, err := metadata.UnmarshalInfo()
	if err != nil || info.PieceLength <= 0 {
		return download.BTResolution{}, fmt.Errorf("%w: info dictionary is invalid", download.ErrBTMetadataInvalid)
	}
	if info.HasV1() && len(info.Pieces)%20 != 0 {
		return download.BTResolution{}, fmt.Errorf("%w: piece hashes are invalid", download.ErrBTMetadataInvalid)
	}
	name, err := safePathSegment(info.BestName())
	if err != nil {
		return download.BTResolution{}, err
	}
	files, total, err := safeFiles(&info, name)
	if err != nil {
		return download.BTResolution{}, err
	}
	if info.HasV1() {
		expectedPieces := total / info.PieceLength
		if total%info.PieceLength != 0 {
			expectedPieces++
		}
		if int64(len(info.Pieces)/20) != expectedPieces {
			return download.BTResolution{}, fmt.Errorf("%w: piece hash count does not match declared data", download.ErrBTMetadataInvalid)
		}
	}
	trackers, err := safeTrackers(metadata.UpvertedAnnounceList().DistinctValues())
	if err != nil {
		return download.BTResolution{}, err
	}
	magnet, err := metadata.MagnetV2()
	if err != nil {
		return download.BTResolution{}, fmt.Errorf("%w: torrent identity is invalid", download.ErrBTMetadataInvalid)
	}
	resolution := download.BTResolution{
		SourceType:        download.BTSourceTorrent,
		Name:              name,
		MetadataAvailable: true,
		Private:           info.Private != nil && *info.Private,
		TotalSize:         total,
		PieceLength:       info.PieceLength,
		Files:             files,
		Trackers:          trackers,
	}
	if magnet.InfoHash.Ok {
		resolution.InfoHash = magnet.InfoHash.Value.HexString()
	}
	if magnet.V2InfoHash.Ok {
		resolution.V2InfoHash = magnet.V2InfoHash.Value.HexString()
	}
	return resolution, nil
}

func safeFiles(info *metainfo.Info, rootName string) ([]download.BTFile, int64, error) {
	upverted := info.UpvertedFiles()
	if len(upverted) == 0 {
		return nil, 0, fmt.Errorf("%w: torrent has no files", download.ErrBTMetadataInvalid)
	}
	if len(upverted) > download.MaxTorrentFiles {
		return nil, 0, download.ErrBTFileLimit
	}
	files := make([]download.BTFile, 0, len(upverted))
	paths := make(map[string]struct{}, len(upverted))
	var total int64
	for sourceIndex, file := range upverted {
		if file.Length < 0 || file.Length > download.MaxTorrentFileSize {
			return nil, 0, download.ErrBTSizeLimit
		}
		if strings.Contains(file.Attr, "l") || len(file.SymlinkPath) != 0 {
			return nil, 0, fmt.Errorf("%w: symbolic links are not allowed", download.ErrBTPathUnsafe)
		}
		if file.Length > download.MaxTorrentTotalSize-total {
			return nil, 0, download.ErrBTSizeLimit
		}
		total += file.Length
		if total > download.MaxTorrentTotalSize {
			return nil, 0, download.ErrBTSizeLimit
		}
		if strings.Contains(file.Attr, "p") {
			continue
		}
		segments := file.BestPath()
		if !info.IsDir() {
			segments = []string{rootName}
		} else {
			segments = append([]string{rootName}, segments...)
		}
		if len(segments) == 0 || len(segments) > download.MaxTorrentPathDepth {
			return nil, 0, download.ErrBTPathUnsafe
		}
		normalized := make([]string, len(segments))
		for index, segment := range segments {
			value, err := safePathSegment(segment)
			if err != nil {
				return nil, 0, err
			}
			normalized[index] = value
		}
		path := strings.Join(normalized, "/")
		identity := strings.ToLower(path)
		if _, exists := paths[identity]; exists {
			return nil, 0, fmt.Errorf("%w: normalized paths collide", download.ErrBTPathUnsafe)
		}
		paths[identity] = struct{}{}
		files = append(files, download.BTFile{Index: sourceIndex, Path: path, Size: file.Length})
	}
	if len(files) == 0 {
		return nil, 0, fmt.Errorf("%w: torrent has no selectable files", download.ErrBTMetadataInvalid)
	}
	return files, total, nil
}

func safePathSegment(raw string) (string, error) {
	value := norm.NFC.String(raw)
	if value == "" || value == "." || value == ".." || value != strings.TrimSpace(value) || strings.HasSuffix(value, ".") || strings.HasSuffix(value, " ") || len(value) > download.MaxTorrentPathSegment || !utf8.ValidString(value) || containsControl(value) || download.SafeFileName(value) != value {
		return "", download.ErrBTPathUnsafe
	}
	return value, nil
}

func safeDisplayName(raw string) string {
	value := norm.NFC.String(strings.TrimSpace(raw))
	if value == "" || !utf8.ValidString(value) {
		return ""
	}
	value = download.SafeFileName(value)
	if len(value) > download.MaxTorrentPathSegment {
		for len(value) > download.MaxTorrentPathSegment {
			_, size := utf8.DecodeLastRuneInString(value)
			value = value[:len(value)-size]
		}
	}
	return value
}

func safeTrackers(values []string) ([]download.BTTracker, error) {
	if len(values) > download.MaxTorrentTrackers {
		return nil, download.ErrBTTrackerInvalid
	}
	result := make([]download.BTTracker, 0, len(values))
	seen := make(map[string]struct{}, len(values))
	for _, raw := range values {
		if len(raw) == 0 || len(raw) > download.MaxTorrentTrackerBytes || containsControl(raw) {
			return nil, download.ErrBTTrackerInvalid
		}
		parsed, err := url.Parse(raw)
		scheme := strings.ToLower(parsed.Scheme)
		if err != nil || parsed.Hostname() == "" || parsed.User != nil || parsed.Fragment != "" || (scheme != "http" && scheme != "https" && scheme != "udp") {
			return nil, download.ErrBTTrackerInvalid
		}
		host := strings.ToLower(parsed.Hostname())
		if port := parsed.Port(); port != "" {
			if _, err := strconv.ParseUint(port, 10, 16); err != nil {
				return nil, download.ErrBTTrackerInvalid
			}
			host = net.JoinHostPort(host, port)
		}
		identity := scheme + "://" + host
		if _, exists := seen[identity]; exists {
			continue
		}
		seen[identity] = struct{}{}
		result = append(result, download.BTTracker{Scheme: scheme, Host: host})
	}
	return result, nil
}

func containsControl(value string) bool {
	for _, character := range value {
		if unicode.IsControl(character) {
			return true
		}
	}
	return false
}

type bencodeValidator struct {
	data   []byte
	index  int
	values int
}

func validateBencode(data []byte) error {
	validator := bencodeValidator{data: data}
	if err := validator.value(0); err != nil {
		return err
	}
	if validator.index != len(data) {
		return errors.New("trailing bencode data")
	}
	return nil
}

func (v *bencodeValidator) value(depth int) error {
	if depth > maxBencodeDepth || v.index >= len(v.data) {
		return errors.New("bencode nesting or length limit exceeded")
	}
	v.values++
	if v.values > maxBencodeValues {
		return errors.New("bencode value limit exceeded")
	}
	switch v.data[v.index] {
	case 'i':
		return v.integer()
	case 'l':
		v.index++
		for v.index < len(v.data) && v.data[v.index] != 'e' {
			if err := v.value(depth + 1); err != nil {
				return err
			}
		}
		return v.end()
	case 'd':
		v.index++
		keys := make(map[string]struct{})
		for v.index < len(v.data) && v.data[v.index] != 'e' {
			key, err := v.stringValue()
			if err != nil {
				return err
			}
			if _, exists := keys[key]; exists {
				return errors.New("duplicate bencode dictionary key")
			}
			keys[key] = struct{}{}
			if err := v.value(depth + 1); err != nil {
				return err
			}
		}
		return v.end()
	default:
		if v.data[v.index] >= '0' && v.data[v.index] <= '9' {
			_, err := v.stringValue()
			return err
		}
		return errors.New("invalid bencode token")
	}
}

func (v *bencodeValidator) integer() error {
	v.index++
	start := v.index
	for v.index < len(v.data) && v.data[v.index] != 'e' {
		v.index++
	}
	if v.index >= len(v.data) || start == v.index {
		return errors.New("unterminated bencode integer")
	}
	value := string(v.data[start:v.index])
	if (len(value) > 1 && value[0] == '0') || strings.HasPrefix(value, "-0") {
		return errors.New("non-canonical bencode integer")
	}
	if _, err := strconv.ParseInt(value, 10, 64); err != nil {
		return err
	}
	v.index++
	return nil
}

func (v *bencodeValidator) stringValue() (string, error) {
	start := v.index
	for v.index < len(v.data) && v.data[v.index] >= '0' && v.data[v.index] <= '9' {
		v.index++
	}
	if start == v.index || v.index >= len(v.data) || v.data[v.index] != ':' {
		return "", errors.New("invalid bencode string length")
	}
	lengthText := string(v.data[start:v.index])
	if len(lengthText) > 1 && lengthText[0] == '0' {
		return "", errors.New("non-canonical bencode string length")
	}
	length, err := strconv.ParseUint(lengthText, 10, 32)
	if err != nil {
		return "", err
	}
	v.index++
	if uint64(len(v.data)-v.index) < length {
		return "", errors.New("truncated bencode string")
	}
	value := string(v.data[v.index : v.index+int(length)])
	v.index += int(length)
	return value, nil
}

func (v *bencodeValidator) end() error {
	if v.index >= len(v.data) || v.data[v.index] != 'e' {
		return errors.New("unterminated bencode collection")
	}
	v.index++
	return nil
}

var _ download.BTResolver = (*Resolver)(nil)
