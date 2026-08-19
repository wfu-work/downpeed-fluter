package releaseartifact

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
)

type NoticeConfig struct {
	RepositoryRoot string
	OutputPath     string
}

type noticeEntry struct {
	Name        string
	Version     string
	Source      string
	LicenseText string
}

type goListPackage struct {
	Module *goListModule `json:"Module"`
}

type goListModule struct {
	Path    string        `json:"Path"`
	Version string        `json:"Version"`
	Dir     string        `json:"Dir"`
	Main    bool          `json:"Main"`
	Replace *goListModule `json:"Replace"`
}

type pubDependencies struct {
	Root     string       `json:"root"`
	Packages []pubPackage `json:"packages"`
	SDKs     []pubSDK     `json:"sdks"`
}

type pubSDK struct {
	Name    string `json:"name"`
	Version string `json:"version"`
}

type pubPackage struct {
	Name               string   `json:"name"`
	Version            string   `json:"version"`
	Kind               string   `json:"kind"`
	Source             string   `json:"source"`
	Dependencies       []string `json:"dependencies"`
	DirectDependencies []string `json:"directDependencies"`
	DevDependencies    []string `json:"devDependencies"`
}

type packageConfiguration struct {
	Packages []configuredPackage `json:"packages"`
}

type configuredPackage struct {
	Name    string `json:"name"`
	RootURI string `json:"rootUri"`
}

func GenerateNotices(ctx context.Context, config NoticeConfig) error {
	root, err := filepath.Abs(config.RepositoryRoot)
	if err != nil {
		return fmt.Errorf("resolve repository root: %w", err)
	}
	if strings.TrimSpace(config.OutputPath) == "" {
		return errors.New("notices output path is required")
	}
	goEntries, err := collectGoNotices(ctx, filepath.Join(root, "backend"))
	if err != nil {
		return err
	}
	dartEntries, err := collectDartNotices(ctx, filepath.Join(root, "app"))
	if err != nil {
		return err
	}
	entries := append(goEntries, dartEntries...)
	sort.Slice(entries, func(left, right int) bool {
		if entries[left].Source != entries[right].Source {
			return entries[left].Source < entries[right].Source
		}
		return entries[left].Name < entries[right].Name
	})
	if err = os.MkdirAll(filepath.Dir(config.OutputPath), 0o755); err != nil {
		return fmt.Errorf("create notices directory: %w", err)
	}
	if err = os.WriteFile(config.OutputPath, formatNotices(entries), 0o644); err != nil {
		return fmt.Errorf("write third-party notices: %w", err)
	}
	return nil
}

func collectGoNotices(ctx context.Context, backendDirectory string) ([]noticeEntry, error) {
	output, err := runCommand(ctx, backendDirectory, "go", "list", "-deps", "-json", "-tags=nosqlite", "./cmd/downpeedlib")
	if err != nil {
		return nil, fmt.Errorf("list Go release dependencies: %w", err)
	}
	decoder := json.NewDecoder(bytes.NewReader(output))
	modules := map[string]goListModule{}
	for {
		var item goListPackage
		if err = decoder.Decode(&item); err != nil {
			if errors.Is(err, io.EOF) {
				break
			}
			return nil, fmt.Errorf("decode Go release dependencies: %w", err)
		}
		if item.Module == nil || item.Module.Main {
			continue
		}
		module := *item.Module
		licenseDirectory := module.Dir
		if module.Replace != nil {
			licenseDirectory = module.Replace.Dir
			if module.Replace.Version != "" {
				module.Version = module.Replace.Version
			}
		}
		module.Dir = licenseDirectory
		modules[module.Path+"@"+module.Version] = module
	}
	entries := make([]noticeEntry, 0, len(modules)+1)
	keys := make([]string, 0, len(modules))
	for key := range modules {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	for _, key := range keys {
		module := modules[key]
		license, readErr := readLicense(module.Dir)
		if readErr != nil {
			return nil, fmt.Errorf("read license for Go module %s: %w", key, readErr)
		}
		entries = append(entries, noticeEntry{
			Name: module.Path, Version: module.Version,
			Source: "Go module", LicenseText: license,
		})
	}
	goRootOutput, err := runCommand(ctx, backendDirectory, "go", "env", "GOROOT")
	if err != nil {
		return nil, fmt.Errorf("locate Go toolchain: %w", err)
	}
	goVersionOutput, err := runCommand(ctx, backendDirectory, "go", "version")
	if err != nil {
		return nil, fmt.Errorf("read Go toolchain version: %w", err)
	}
	goLicense, err := readLicense(strings.TrimSpace(string(goRootOutput)))
	if err != nil {
		return nil, fmt.Errorf("read Go toolchain license: %w", err)
	}
	entries = append(entries, noticeEntry{
		Name: "Go toolchain", Version: strings.TrimSpace(string(goVersionOutput)),
		Source: "Toolchain", LicenseText: goLicense,
	})
	return entries, nil
}

func collectDartNotices(ctx context.Context, appDirectory string) ([]noticeEntry, error) {
	output, err := runCommand(ctx, appDirectory, "dart", "pub", "deps", "--json")
	if err != nil {
		return nil, fmt.Errorf("list Dart release dependencies: %w", err)
	}
	var dependencies pubDependencies
	if err = json.Unmarshal(output, &dependencies); err != nil {
		return nil, fmt.Errorf("decode Dart release dependencies: %w", err)
	}
	configurationPath := filepath.Join(appDirectory, ".dart_tool", "package_config.json")
	configurationBytes, err := os.ReadFile(configurationPath)
	if err != nil {
		return nil, fmt.Errorf("read Dart package configuration: %w", err)
	}
	var configuration packageConfiguration
	if err = json.Unmarshal(configurationBytes, &configuration); err != nil {
		return nil, fmt.Errorf("decode Dart package configuration: %w", err)
	}
	packageDirectories := make(map[string]string, len(configuration.Packages))
	for _, item := range configuration.Packages {
		packageDirectories[item.Name], err = resolvePackageURI(filepath.Dir(configurationPath), item.RootURI)
		if err != nil {
			return nil, fmt.Errorf("resolve Dart package %s: %w", item.Name, err)
		}
	}
	packages := make(map[string]pubPackage, len(dependencies.Packages))
	for _, item := range dependencies.Packages {
		packages[item.Name] = item
	}
	runtimePackages, err := runtimePackageNames(dependencies.Root, packages)
	if err != nil {
		return nil, err
	}
	entries := make([]noticeEntry, 0, len(runtimePackages)+1)
	flutterVersion := "unknown"
	for _, sdk := range dependencies.SDKs {
		if sdk.Name == "Flutter" && sdk.Version != "" {
			flutterVersion = sdk.Version
			break
		}
	}
	flutterAdded := false
	for _, name := range runtimePackages {
		item := packages[name]
		if item.Source == "sdk" {
			if flutterAdded || name != "flutter" {
				continue
			}
			flutterRoot := filepath.Dir(filepath.Dir(packageDirectories[name]))
			license, readErr := readLicense(flutterRoot)
			if readErr != nil {
				return nil, fmt.Errorf("read Flutter SDK license: %w", readErr)
			}
			entries = append(entries, noticeEntry{
				Name: "Flutter SDK", Version: flutterVersion,
				Source: "Toolchain", LicenseText: license,
			})
			flutterAdded = true
			continue
		}
		directory := packageDirectories[name]
		license, readErr := readLicense(directory)
		if readErr != nil {
			return nil, fmt.Errorf("read license for Dart package %s: %w", name, readErr)
		}
		entries = append(entries, noticeEntry{
			Name: name, Version: item.Version,
			Source: "Dart package", LicenseText: license,
		})
	}
	return entries, nil
}

func runtimePackageNames(root string, packages map[string]pubPackage) ([]string, error) {
	rootPackage, ok := packages[root]
	if !ok {
		return nil, errors.New("Dart dependency graph has no root package")
	}
	seen := map[string]bool{root: true}
	queue := append([]string(nil), rootPackage.DirectDependencies...)
	for len(queue) > 0 {
		name := queue[0]
		queue = queue[1:]
		if seen[name] {
			continue
		}
		item, exists := packages[name]
		if !exists {
			return nil, fmt.Errorf("Dart dependency graph references unknown package %s", name)
		}
		seen[name] = true
		queue = append(queue, item.Dependencies...)
	}
	result := make([]string, 0, len(seen)-1)
	for name := range seen {
		if name != root {
			result = append(result, name)
		}
	}
	sort.Strings(result)
	return result, nil
}

func resolvePackageURI(baseDirectory, value string) (string, error) {
	parsed, err := url.Parse(value)
	if err != nil {
		return "", err
	}
	if parsed.Scheme != "" && parsed.Scheme != "file" {
		return "", fmt.Errorf("unsupported package URI scheme %q", parsed.Scheme)
	}
	path, err := url.PathUnescape(parsed.Path)
	if err != nil {
		return "", err
	}
	if parsed.Scheme == "file" {
		path = normalizeFileURIPath(runtime.GOOS, parsed.Host, path)
		return filepath.Clean(filepath.FromSlash(path)), nil
	}
	return filepath.Clean(filepath.Join(baseDirectory, filepath.FromSlash(path))), nil
}

func normalizeFileURIPath(goos, host, path string) string {
	if goos == "windows" && len(path) >= 3 && path[0] == '/' && path[2] == ':' {
		path = path[1:]
	}
	if host != "" {
		path = "//" + host + "/" + strings.TrimPrefix(path, "/")
	}
	return path
}

func readLicense(directory string) (string, error) {
	for _, name := range []string{
		"LICENSE", "LICENSE.md", "LICENSE.txt", "LICENCE", "COPYING", "NOTICE",
	} {
		content, err := os.ReadFile(filepath.Join(directory, name))
		if err == nil {
			text := strings.TrimSpace(string(content))
			if text != "" {
				return text, nil
			}
		}
		if !errors.Is(err, os.ErrNotExist) {
			return "", err
		}
	}
	return "", errors.New("no supported license file found")
}

func formatNotices(entries []noticeEntry) []byte {
	var output strings.Builder
	output.WriteString("DOWNPEED THIRD-PARTY NOTICES\n\n")
	output.WriteString("This file is generated from the release dependency graphs.\n")
	output.WriteString("Development-only dependencies are excluded.\n")
	for _, entry := range entries {
		output.WriteString("\n===============================================================================\n")
		output.WriteString(entry.Name)
		output.WriteByte('\n')
		output.WriteString("Source: ")
		output.WriteString(entry.Source)
		output.WriteByte('\n')
		if entry.Version != "" {
			output.WriteString("Version: ")
			output.WriteString(entry.Version)
			output.WriteByte('\n')
		}
		output.WriteString("===============================================================================\n")
		output.WriteString(strings.TrimSpace(entry.LicenseText))
		output.WriteByte('\n')
	}
	return []byte(output.String())
}

func runCommand(ctx context.Context, directory, name string, arguments ...string) ([]byte, error) {
	command := exec.CommandContext(ctx, name, arguments...)
	command.Dir = directory
	var stderr bytes.Buffer
	command.Stderr = &stderr
	output, err := command.Output()
	if err != nil {
		message := strings.TrimSpace(stderr.String())
		if message != "" {
			return nil, fmt.Errorf("%w: %s", err, message)
		}
		return nil, err
	}
	return output, nil
}
