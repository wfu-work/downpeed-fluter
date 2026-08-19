package releaseartifact

import (
	"bufio"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

const manifestSchemaVersion = 1

type ManifestConfig struct {
	Product       string
	Version       string
	BuildNumber   string
	Commit        string
	BuildDate     string
	Channel       string
	Platform      string
	Architecture  string
	Signing       string
	ArtifactPath  string
	NoticesPath   string
	ManifestPath  string
	ChecksumsPath string
}

type Manifest struct {
	SchemaVersion int          `json:"schemaVersion"`
	Product       string       `json:"product"`
	Version       string       `json:"version"`
	BuildNumber   string       `json:"buildNumber"`
	Commit        string       `json:"commit"`
	BuildDate     string       `json:"buildDate"`
	Channel       string       `json:"channel"`
	Artifact      ManifestFile `json:"artifact"`
	Notices       ManifestFile `json:"notices"`
	Platform      string       `json:"platform"`
	Architecture  string       `json:"architecture"`
	Signing       string       `json:"signing"`
}

type ManifestFile struct {
	File   string `json:"file"`
	Size   int64  `json:"size"`
	SHA256 string `json:"sha256"`
}

func WriteManifest(config ManifestConfig) error {
	if err := config.validate(); err != nil {
		return err
	}
	artifact, err := inspectFile(config.ArtifactPath)
	if err != nil {
		return fmt.Errorf("inspect release artifact: %w", err)
	}
	notices, err := inspectFile(config.NoticesPath)
	if err != nil {
		return fmt.Errorf("inspect third-party notices: %w", err)
	}
	manifest := Manifest{
		SchemaVersion: manifestSchemaVersion,
		Product:       config.Product,
		Version:       config.Version,
		BuildNumber:   config.BuildNumber,
		Commit:        config.Commit,
		BuildDate:     config.BuildDate,
		Channel:       config.Channel,
		Platform:      config.Platform,
		Architecture:  config.Architecture,
		Signing:       config.Signing,
		Artifact:      artifact,
		Notices:       notices,
	}
	encoded, err := json.MarshalIndent(manifest, "", "  ")
	if err != nil {
		return fmt.Errorf("encode release manifest: %w", err)
	}
	if err = os.MkdirAll(filepath.Dir(config.ManifestPath), 0o755); err != nil {
		return fmt.Errorf("create manifest directory: %w", err)
	}
	if err = os.WriteFile(config.ManifestPath, append(encoded, '\n'), 0o644); err != nil {
		return fmt.Errorf("write release manifest: %w", err)
	}
	return WriteChecksums(
		[]string{config.ArtifactPath, config.NoticesPath, config.ManifestPath},
		config.ChecksumsPath,
	)
}

func VerifyManifest(manifestPath, checksumsPath string) error {
	encoded, err := os.ReadFile(manifestPath)
	if err != nil {
		return fmt.Errorf("read release manifest: %w", err)
	}
	decoder := json.NewDecoder(strings.NewReader(string(encoded)))
	decoder.DisallowUnknownFields()
	var manifest Manifest
	if err = decoder.Decode(&manifest); err != nil {
		return fmt.Errorf("decode release manifest: %w", err)
	}
	if err = ensureJSONEnd(decoder); err != nil {
		return fmt.Errorf("decode release manifest: %w", err)
	}
	if manifest.SchemaVersion != manifestSchemaVersion {
		return fmt.Errorf("unsupported release manifest schema %d", manifest.SchemaVersion)
	}
	if strings.TrimSpace(manifest.Product) == "" || strings.TrimSpace(manifest.Version) == "" ||
		strings.TrimSpace(manifest.Platform) == "" || strings.TrimSpace(manifest.Architecture) == "" {
		return errors.New("release manifest is missing required metadata")
	}
	directory := filepath.Dir(manifestPath)
	for label, expected := range map[string]ManifestFile{
		"artifact": manifest.Artifact,
		"notices":  manifest.Notices,
	} {
		if filepath.Base(expected.File) != expected.File || expected.File == "." || expected.File == "" {
			return fmt.Errorf("%s file name is unsafe", label)
		}
		actual, inspectErr := inspectFile(filepath.Join(directory, expected.File))
		if inspectErr != nil {
			return fmt.Errorf("inspect %s: %w", label, inspectErr)
		}
		if actual.Size != expected.Size || actual.SHA256 != expected.SHA256 {
			return fmt.Errorf("%s does not match the release manifest", label)
		}
	}
	return VerifyChecksums(checksumsPath)
}

func WriteChecksums(paths []string, outputPath string) error {
	entries := make([]ManifestFile, 0, len(paths))
	for _, path := range paths {
		entry, err := inspectFile(path)
		if err != nil {
			return err
		}
		entries = append(entries, entry)
	}
	sort.Slice(entries, func(left, right int) bool {
		return entries[left].File < entries[right].File
	})
	var output strings.Builder
	for _, entry := range entries {
		fmt.Fprintf(&output, "%s  %s\n", entry.SHA256, entry.File)
	}
	if err := os.WriteFile(outputPath, []byte(output.String()), 0o644); err != nil {
		return fmt.Errorf("write release checksums: %w", err)
	}
	return nil
}

func VerifyChecksums(path string) error {
	file, err := os.Open(path)
	if err != nil {
		return fmt.Errorf("open release checksums: %w", err)
	}
	defer file.Close()
	directory := filepath.Dir(path)
	scanner := bufio.NewScanner(file)
	count := 0
	for scanner.Scan() {
		line := scanner.Text()
		parts := strings.SplitN(line, "  ", 2)
		if len(parts) != 2 || len(parts[0]) != sha256.Size*2 || filepath.Base(parts[1]) != parts[1] {
			return fmt.Errorf("invalid checksum line %q", line)
		}
		if _, err = hex.DecodeString(parts[0]); err != nil {
			return fmt.Errorf("invalid checksum for %q", parts[1])
		}
		actual, inspectErr := inspectFile(filepath.Join(directory, parts[1]))
		if inspectErr != nil {
			return inspectErr
		}
		if actual.SHA256 != parts[0] {
			return fmt.Errorf("checksum mismatch for %q", parts[1])
		}
		count++
	}
	if err = scanner.Err(); err != nil {
		return fmt.Errorf("read release checksums: %w", err)
	}
	if count == 0 {
		return errors.New("release checksums are empty")
	}
	return nil
}

func (config ManifestConfig) validate() error {
	required := map[string]string{
		"product": config.Product, "version": config.Version,
		"build number": config.BuildNumber, "commit": config.Commit,
		"build date": config.BuildDate, "channel": config.Channel,
		"platform": config.Platform, "architecture": config.Architecture,
		"signing": config.Signing, "artifact": config.ArtifactPath,
		"notices": config.NoticesPath, "manifest": config.ManifestPath,
		"checksums": config.ChecksumsPath,
	}
	for name, value := range required {
		if strings.TrimSpace(value) == "" {
			return fmt.Errorf("%s is required", name)
		}
	}
	if _, err := time.Parse(time.RFC3339, config.BuildDate); err != nil {
		return errors.New("build date must use RFC3339")
	}
	return nil
}

func inspectFile(path string) (ManifestFile, error) {
	file, err := os.Open(path)
	if err != nil {
		return ManifestFile{}, err
	}
	defer file.Close()
	info, err := file.Stat()
	if err != nil {
		return ManifestFile{}, err
	}
	if !info.Mode().IsRegular() {
		return ManifestFile{}, errors.New("release input must be a regular file")
	}
	hash := sha256.New()
	if _, err = io.Copy(hash, file); err != nil {
		return ManifestFile{}, err
	}
	return ManifestFile{
		File:   filepath.Base(path),
		Size:   info.Size(),
		SHA256: hex.EncodeToString(hash.Sum(nil)),
	}, nil
}

func ensureJSONEnd(decoder *json.Decoder) error {
	var extra any
	if err := decoder.Decode(&extra); !errors.Is(err, io.EOF) {
		if err == nil {
			return errors.New("multiple JSON values")
		}
		return err
	}
	return nil
}
