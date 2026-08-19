package releaseartifact

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestWriteAndVerifyManifest(t *testing.T) {
	directory := t.TempDir()
	artifact := filepath.Join(directory, "downpeed.zip")
	notices := filepath.Join(directory, "THIRD_PARTY_NOTICES.txt")
	manifest := filepath.Join(directory, "release-manifest.json")
	checksums := filepath.Join(directory, "SHA256SUMS")
	if err := os.WriteFile(artifact, []byte("artifact"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(notices, []byte("notices"), 0o644); err != nil {
		t.Fatal(err)
	}
	err := WriteManifest(ManifestConfig{
		Product: "Downpeed", Version: "1.0.0", BuildNumber: "42",
		Commit: "abcdef0", BuildDate: "2026-08-19T08:00:00Z", Channel: "test",
		Platform: "macos", Architecture: "arm64", Signing: "adhoc",
		ArtifactPath: artifact, NoticesPath: notices,
		ManifestPath: manifest, ChecksumsPath: checksums,
	})
	if err != nil {
		t.Fatal(err)
	}
	if err = VerifyManifest(manifest, checksums); err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(artifact, []byte("changed"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err = VerifyManifest(manifest, checksums); err == nil {
		t.Fatal("VerifyManifest() accepted a modified artifact")
	}
}

func TestRuntimePackageNamesExcludesDevGraph(t *testing.T) {
	packages := map[string]pubPackage{
		"app":       {Name: "app", DirectDependencies: []string{"runtime"}, DevDependencies: []string{"test"}},
		"runtime":   {Name: "runtime", Dependencies: []string{"shared"}},
		"shared":    {Name: "shared"},
		"test":      {Name: "test", Dependencies: []string{"test_only"}},
		"test_only": {Name: "test_only"},
	}
	names, err := runtimePackageNames("app", packages)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Join(names, ",") != "runtime,shared" {
		t.Fatalf("runtime packages = %v", names)
	}
}

func TestFormatNoticesIsDeterministic(t *testing.T) {
	result := string(formatNotices([]noticeEntry{{
		Name: "example", Version: "1.2.3", Source: "Dart package",
		LicenseText: "license text\n",
	}}))
	if !strings.Contains(result, "example\nSource: Dart package\nVersion: 1.2.3") ||
		!strings.HasSuffix(result, "license text\n") {
		t.Fatalf("formatNotices() = %q", result)
	}
}

func TestNormalizeWindowsFileURIPath(t *testing.T) {
	if got := normalizeFileURIPath("windows", "", "/C:/pub/cache"); got != "C:/pub/cache" {
		t.Fatalf("Windows drive path = %q", got)
	}
	if got := normalizeFileURIPath("windows", "server", "/share/cache"); got != "//server/share/cache" {
		t.Fatalf("Windows UNC path = %q", got)
	}
}
