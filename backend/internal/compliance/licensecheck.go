package compliance

import (
	"bufio"
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
)

type Policy struct {
	SchemaVersion                 int             `json:"schemaVersion"`
	ReviewedAt                    string          `json:"reviewedAt"`
	Status                        string          `json:"status"`
	Component                     ComponentPolicy `json:"component"`
	AllowedLicenses               []string        `json:"allowedLicenses"`
	ReviewRequiredLicensePrefixes []string        `json:"reviewRequiredLicensePrefixes"`
	DeniedLicensePrefixes         []string        `json:"deniedLicensePrefixes"`
	Conditions                    []string        `json:"conditions"`
}

type ComponentPolicy struct {
	ModulePath     string `json:"modulePath"`
	Version        string `json:"version"`
	ModuleSum      string `json:"moduleSum"`
	GoModSum       string `json:"goModSum"`
	GoModSHA256    string `json:"goModSHA256"`
	License        string `json:"license"`
	LicenseFile    string `json:"licenseFile"`
	LicenseSHA256  string `json:"licenseSHA256"`
	SecurityFile   string `json:"securityFile"`
	SecuritySHA256 string `json:"securitySHA256"`
}

type BuildModule struct {
	Path     string
	Version  string
	Dir      string
	Replaced bool
}

type ModuleLicense struct {
	Module   BuildModule
	Licenses []string
}

func LoadPolicy(path string) (Policy, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return Policy{}, fmt.Errorf("read policy: %w", err)
	}

	var policy Policy
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&policy); err != nil {
		return Policy{}, fmt.Errorf("decode policy: %w", err)
	}
	if err := validatePolicy(policy); err != nil {
		return Policy{}, err
	}
	return policy, nil
}

func validatePolicy(policy Policy) error {
	if policy.SchemaVersion != 1 {
		return fmt.Errorf("unsupported policy schema version %d", policy.SchemaVersion)
	}
	if policy.Status != "approved-with-conditions" {
		return fmt.Errorf("component status %q is not approved", policy.Status)
	}
	component := policy.Component
	if component.ModulePath == "" || component.Version == "" || component.ModuleSum == "" || component.GoModSum == "" || component.GoModSHA256 == "" {
		return errors.New("component module path, version and sums are required")
	}
	if component.License == "" || component.LicenseFile == "" || component.LicenseSHA256 == "" {
		return errors.New("component license evidence is incomplete")
	}
	if component.SecurityFile == "" || component.SecuritySHA256 == "" {
		return errors.New("component security policy evidence is incomplete")
	}
	if len(policy.AllowedLicenses) == 0 || len(policy.DeniedLicensePrefixes) == 0 {
		return errors.New("license allow and deny policies are required")
	}
	return nil
}

func VerifyCandidate(policy Policy, moduleCache string) error {
	modulePath, err := escapeModuleCachePart(policy.Component.ModulePath)
	if err != nil {
		return err
	}
	version, err := escapeModuleCachePart(policy.Component.Version)
	if err != nil {
		return err
	}
	componentDir := filepath.Join(moduleCache, filepath.FromSlash(modulePath+"@"+version))
	downloadDir := filepath.Join(moduleCache, "cache", "download", filepath.FromSlash(modulePath), "@v")
	archiveSumPath := filepath.Join(downloadDir, version+".ziphash")

	var failures []error
	if err := verifyFileHash(filepath.Join(componentDir, policy.Component.LicenseFile), policy.Component.LicenseSHA256); err != nil {
		failures = append(failures, fmt.Errorf("license evidence: %w", err))
	} else {
		licenses, err := DetectLicenses(componentDir)
		if err != nil {
			failures = append(failures, fmt.Errorf("detect component license: %w", err))
		} else if !contains(licenses, policy.Component.License) {
			failures = append(failures, fmt.Errorf("expected %s, detected %s", policy.Component.License, strings.Join(licenses, ", ")))
		}
	}
	if err := verifyFileHash(filepath.Join(componentDir, policy.Component.SecurityFile), policy.Component.SecuritySHA256); err != nil {
		failures = append(failures, fmt.Errorf("security policy evidence: %w", err))
	}
	if err := verifyFileHash(filepath.Join(downloadDir, version+".mod"), policy.Component.GoModSHA256); err != nil {
		failures = append(failures, fmt.Errorf("module definition evidence: %w", err))
	}
	archiveSum, err := os.ReadFile(archiveSumPath)
	if err != nil {
		failures = append(failures, fmt.Errorf("read module archive sum: %w", err))
	} else if strings.TrimSpace(string(archiveSum)) != policy.Component.ModuleSum {
		failures = append(failures, fmt.Errorf("module archive sum does not match policy"))
	}
	return errors.Join(failures...)
}

func VerifyPinnedModule(policy Policy, goModPath, goSumPath string) error {
	goMod, err := os.ReadFile(goModPath)
	if err != nil {
		return fmt.Errorf("read go.mod: %w", err)
	}
	if !hasRequiredModule(goMod, policy.Component.ModulePath, policy.Component.Version) {
		return fmt.Errorf("%s must be pinned to %s in go.mod", policy.Component.ModulePath, policy.Component.Version)
	}
	if hasModuleReplacement(goMod, policy.Component.ModulePath) {
		return fmt.Errorf("%s must not be replaced", policy.Component.ModulePath)
	}

	goSum, err := os.ReadFile(goSumPath)
	if err != nil {
		return fmt.Errorf("read go.sum: %w", err)
	}
	wantModule := strings.Join([]string{policy.Component.ModulePath, policy.Component.Version, policy.Component.ModuleSum}, " ")
	wantGoMod := strings.Join([]string{policy.Component.ModulePath, policy.Component.Version + "/go.mod", policy.Component.GoModSum}, " ")
	lines := lineSet(goSum)
	var failures []error
	if !lines[wantModule] {
		failures = append(failures, errors.New("module content sum is missing or changed"))
	}
	if !lines[wantGoMod] {
		failures = append(failures, errors.New("module go.mod sum is missing or changed"))
	}
	return errors.Join(failures...)
}

func ListBuildModules(ctx context.Context, backendDir string) ([]BuildModule, error) {
	command := exec.CommandContext(ctx, "go", "list", "-deps", "-json", "./...")
	command.Dir = backendDir
	command.Env = append(os.Environ(), "GOWORK=off")
	output, err := command.Output()
	if err != nil {
		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) {
			return nil, fmt.Errorf("go list failed: %s", strings.TrimSpace(string(exitErr.Stderr)))
		}
		return nil, fmt.Errorf("run go list: %w", err)
	}

	type listedModule struct {
		Path    string
		Version string
		Dir     string
		Main    bool
		Replace *listedModule
	}
	type listedPackage struct {
		Standard bool
		Module   *listedModule
	}

	modules := make(map[string]BuildModule)
	decoder := json.NewDecoder(bytes.NewReader(output))
	for decoder.More() {
		var pkg listedPackage
		if err := decoder.Decode(&pkg); err != nil {
			return nil, fmt.Errorf("decode go list output: %w", err)
		}
		if pkg.Standard || pkg.Module == nil || pkg.Module.Main {
			continue
		}
		module := BuildModule{Path: pkg.Module.Path, Version: pkg.Module.Version, Dir: pkg.Module.Dir}
		if pkg.Module.Replace != nil {
			module.Dir = pkg.Module.Replace.Dir
			module.Replaced = true
		}
		modules[module.Path+"@"+module.Version] = module
	}

	result := make([]BuildModule, 0, len(modules))
	for _, module := range modules {
		result = append(result, module)
	}
	sort.Slice(result, func(i, j int) bool {
		if result[i].Path == result[j].Path {
			return result[i].Version < result[j].Version
		}
		return result[i].Path < result[j].Path
	})
	return result, nil
}

func VerifyBuildLicenses(policy Policy, modules []BuildModule) ([]ModuleLicense, error) {
	allowed := make(map[string]bool, len(policy.AllowedLicenses))
	for _, license := range policy.AllowedLicenses {
		allowed[license] = true
	}

	componentFound := false
	report := make([]ModuleLicense, 0, len(modules))
	var failures []error
	for _, module := range modules {
		if module.Path == policy.Component.ModulePath && module.Version == policy.Component.Version {
			componentFound = true
		}
		if module.Replaced {
			failures = append(failures, fmt.Errorf("%s@%s uses a replacement and requires manual review", module.Path, module.Version))
			continue
		}
		licenses, err := DetectLicenses(module.Dir)
		if err != nil {
			failures = append(failures, fmt.Errorf("%s@%s: %w", module.Path, module.Version, err))
			continue
		}
		report = append(report, ModuleLicense{Module: module, Licenses: licenses})

		approved := false
		blocked := false
		for _, license := range licenses {
			if hasPrefix(license, policy.DeniedLicensePrefixes) {
				failures = append(failures, fmt.Errorf("%s@%s uses denied license %s", module.Path, module.Version, license))
				blocked = true
			}
			if hasPrefix(license, policy.ReviewRequiredLicensePrefixes) {
				failures = append(failures, fmt.Errorf("%s@%s uses review-required license %s", module.Path, module.Version, license))
				blocked = true
			}
			approved = approved || allowed[license]
		}
		if !approved && !blocked {
			failures = append(failures, fmt.Errorf("%s@%s has no approved license: %s", module.Path, module.Version, strings.Join(licenses, ", ")))
		}
	}
	if !componentFound {
		failures = append(failures, fmt.Errorf("%s@%s is not in the compiled backend dependency graph", policy.Component.ModulePath, policy.Component.Version))
	}
	return report, errors.Join(failures...)
}

func DetectLicenses(moduleDir string) ([]string, error) {
	entries, err := os.ReadDir(moduleDir)
	if err != nil {
		return nil, fmt.Errorf("read module directory: %w", err)
	}

	licenses := make(map[string]bool)
	for _, entry := range entries {
		if entry.IsDir() || !isLicenseFilename(entry.Name()) {
			continue
		}
		data, err := os.ReadFile(filepath.Join(moduleDir, entry.Name()))
		if err != nil {
			return nil, fmt.Errorf("read %s: %w", entry.Name(), err)
		}
		for _, license := range detectLicenseText(data) {
			licenses[license] = true
		}
	}
	if len(licenses) == 0 {
		return nil, errors.New("license is missing or unrecognized")
	}

	result := make([]string, 0, len(licenses))
	for license := range licenses {
		result = append(result, license)
	}
	sort.Strings(result)
	return result, nil
}

func detectLicenseText(data []byte) []string {
	upper := strings.ToUpper(string(data))
	normalized := strings.Join(strings.Fields(upper), " ")
	header := normalized
	if len(header) > 1024 {
		header = header[:1024]
	}

	var licenses []string
	switch {
	case strings.Contains(header, "MOZILLA PUBLIC LICENSE VERSION 2.0"):
		licenses = append(licenses, "MPL-2.0")
	case strings.Contains(header, "GNU AFFERO GENERAL PUBLIC LICENSE"):
		licenses = append(licenses, gnuVersion(header, "AGPL"))
	case strings.Contains(header, "GNU LESSER GENERAL PUBLIC LICENSE"):
		licenses = append(licenses, gnuVersion(header, "LGPL"))
	case strings.Contains(header, "GNU GENERAL PUBLIC LICENSE"):
		licenses = append(licenses, gnuVersion(header, "GPL"))
	}
	if strings.Contains(normalized, "APACHE LICENSE") && strings.Contains(normalized, "VERSION 2.0") {
		licenses = append(licenses, "Apache-2.0")
	}
	if strings.Contains(normalized, "PERMISSION IS HEREBY GRANTED, FREE OF CHARGE, TO ANY PERSON OBTAINING A COPY") {
		licenses = append(licenses, "MIT")
	}
	if strings.Contains(normalized, "REDISTRIBUTION AND USE IN SOURCE AND BINARY FORMS, WITH OR WITHOUT MODIFICATION") {
		if strings.Contains(normalized, "NEITHER THE NAME") || strings.Contains(normalized, "NOR THE NAMES OF ITS CONTRIBUTORS") {
			licenses = append(licenses, "BSD-3-Clause")
		} else {
			licenses = append(licenses, "BSD-2-Clause")
		}
	}
	if strings.Contains(normalized, "PERMISSION TO USE, COPY, MODIFY, AND/OR DISTRIBUTE THIS SOFTWARE FOR ANY PURPOSE WITH OR WITHOUT FEE") {
		licenses = append(licenses, "ISC")
	}
	if strings.Contains(normalized, "CC0 1.0 UNIVERSAL") || strings.Contains(normalized, "CREATIVE COMMONS ZERO V1.0 UNIVERSAL") {
		licenses = append(licenses, "CC0-1.0")
	}
	if strings.Contains(normalized, "THIS IS FREE AND UNENCUMBERED SOFTWARE RELEASED INTO THE PUBLIC DOMAIN") {
		licenses = append(licenses, "Unlicense")
	}
	return uniqueSorted(licenses)
}

func gnuVersion(header, family string) string {
	for _, version := range []string{"3", "2.1", "2"} {
		if strings.Contains(header, "VERSION "+version) {
			return family + "-" + version
		}
	}
	return family + "-unknown"
}

func verifyFileHash(path, expected string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("read %s: %w", filepath.Base(path), err)
	}
	actual := sha256.Sum256(data)
	if hex.EncodeToString(actual[:]) != expected {
		return fmt.Errorf("%s SHA-256 does not match policy", filepath.Base(path))
	}
	return nil
}

func escapeModuleCachePart(value string) (string, error) {
	if value == "" || filepath.IsAbs(value) || strings.Contains(value, "\\") {
		return "", fmt.Errorf("invalid module cache value %q", value)
	}
	parts := strings.Split(value, "/")
	for _, part := range parts {
		if part == "" || part == "." || part == ".." || strings.Contains(part, "!") {
			return "", fmt.Errorf("invalid module cache value %q", value)
		}
	}
	var escaped strings.Builder
	for _, char := range value {
		if char >= 'A' && char <= 'Z' {
			escaped.WriteByte('!')
			escaped.WriteRune(char + ('a' - 'A'))
		} else {
			escaped.WriteRune(char)
		}
	}
	return escaped.String(), nil
}

func hasRequiredModule(data []byte, modulePath, version string) bool {
	scanner := bufio.NewScanner(bytes.NewReader(data))
	for scanner.Scan() {
		line := strings.TrimSpace(strings.SplitN(scanner.Text(), "//", 2)[0])
		fields := strings.Fields(line)
		if len(fields) >= 3 && fields[0] == "require" && fields[1] == modulePath && fields[2] == version {
			return true
		}
		if len(fields) >= 2 && fields[0] == modulePath && fields[1] == version {
			return true
		}
	}
	return false
}

func hasModuleReplacement(data []byte, modulePath string) bool {
	scanner := bufio.NewScanner(bytes.NewReader(data))
	for scanner.Scan() {
		line := strings.TrimSpace(strings.SplitN(scanner.Text(), "//", 2)[0])
		fields := strings.Fields(line)
		if len(fields) >= 2 && fields[0] == "replace" && fields[1] == modulePath {
			return true
		}
		if len(fields) >= 1 && fields[0] == modulePath && strings.Contains(line, "=>") {
			return true
		}
	}
	return false
}

func lineSet(data []byte) map[string]bool {
	result := make(map[string]bool)
	scanner := bufio.NewScanner(bytes.NewReader(data))
	for scanner.Scan() {
		result[strings.TrimSpace(scanner.Text())] = true
	}
	return result
}

func isLicenseFilename(name string) bool {
	upper := strings.ToUpper(name)
	return upper == "LICENSE" || strings.HasPrefix(upper, "LICENSE.") || strings.HasPrefix(upper, "LICENSE-") || strings.HasPrefix(upper, "LICENSE_") ||
		upper == "COPYING" || strings.HasPrefix(upper, "COPYING.") || upper == "UNLICENSE"
}

func contains(values []string, wanted string) bool {
	for _, value := range values {
		if value == wanted {
			return true
		}
	}
	return false
}

func hasPrefix(value string, prefixes []string) bool {
	for _, prefix := range prefixes {
		if strings.HasPrefix(value, prefix) {
			return true
		}
	}
	return false
}

func uniqueSorted(values []string) []string {
	seen := make(map[string]bool, len(values))
	for _, value := range values {
		seen[value] = true
	}
	result := make([]string, 0, len(seen))
	for value := range seen {
		result = append(result, value)
	}
	sort.Strings(result)
	return result
}
