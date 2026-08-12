package compliance

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestDetectLicenseTextDoesNotTreatMPLAsGPL(t *testing.T) {
	text := []byte("Mozilla Public License Version 2.0\nSecondary License means the GNU General Public License, Version 2.0")
	want := []string{"MPL-2.0"}
	if got := detectLicenseText(text); !reflect.DeepEqual(got, want) {
		t.Fatalf("detectLicenseText() = %v, want %v", got, want)
	}
}

func TestDetectLicenseTextHandlesMPLCommaAndISCVariant(t *testing.T) {
	tests := map[string]struct {
		text string
		want []string
	}{
		"MPL comma": {
			text: "Mozilla Public License, version 2.0",
			want: []string{"MPL-2.0"},
		},
		"ISC distribute": {
			text: "Permission to use, copy, modify, and distribute this software for any purpose with or without fee is hereby granted",
			want: []string{"ISC"},
		},
	}
	for name, test := range tests {
		t.Run(name, func(t *testing.T) {
			if got := detectLicenseText([]byte(test.text)); !reflect.DeepEqual(got, test.want) {
				t.Fatalf("detectLicenseText() = %v, want %v", got, test.want)
			}
		})
	}
}

func TestDetectLicenseTextHandlesWrappedBSD(t *testing.T) {
	text := []byte("Redistribution and use in source and binary forms, with or without\nmodification, are permitted provided that the following conditions are met:\nNeither the name of the owner nor the names of its contributors")
	want := []string{"BSD-3-Clause"}
	if got := detectLicenseText(text); !reflect.DeepEqual(got, want) {
		t.Fatalf("detectLicenseText() = %v, want %v", got, want)
	}
}

func TestDetectLicenses(t *testing.T) {
	moduleDir := t.TempDir()
	license := "MIT License\n\nPermission is hereby granted, free of charge, to any person obtaining a copy"
	if err := os.WriteFile(filepath.Join(moduleDir, "LICENSE"), []byte(license), 0o600); err != nil {
		t.Fatal(err)
	}

	got, err := DetectLicenses(moduleDir)
	if err != nil {
		t.Fatal(err)
	}
	want := []string{"MIT"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("DetectLicenses() = %v, want %v", got, want)
	}
}

func TestDetectLicensesRejectsUnknownText(t *testing.T) {
	moduleDir := t.TempDir()
	if err := os.WriteFile(filepath.Join(moduleDir, "LICENSE"), []byte("custom terms"), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := DetectLicenses(moduleDir); err == nil {
		t.Fatal("DetectLicenses() error = nil, want unknown license error")
	}
}

func TestVerifyPinnedModule(t *testing.T) {
	dir := t.TempDir()
	goModPath := filepath.Join(dir, "go.mod")
	goSumPath := filepath.Join(dir, "go.sum")
	if err := os.WriteFile(goModPath, []byte("module example.com/app\n\nrequire example.com/component v1.2.3\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	goSum := "example.com/component v1.2.3 h1:module\nexample.com/component v1.2.3/go.mod h1:gomod\n"
	if err := os.WriteFile(goSumPath, []byte(goSum), 0o600); err != nil {
		t.Fatal(err)
	}
	policy := Policy{Component: ComponentPolicy{
		ModulePath: "example.com/component",
		Version:    "v1.2.3",
		ModuleSum:  "h1:module",
		GoModSum:   "h1:gomod",
	}}
	if err := VerifyPinnedModule(policy, goModPath, goSumPath); err != nil {
		t.Fatal(err)
	}
}

func TestEscapeModuleCachePart(t *testing.T) {
	got, err := escapeModuleCachePart("github.com/RoaringBitmap/roaring")
	if err != nil {
		t.Fatal(err)
	}
	if want := "github.com/!roaring!bitmap/roaring"; got != want {
		t.Fatalf("escapeModuleCachePart() = %q, want %q", got, want)
	}
}

func TestLicenseFilenames(t *testing.T) {
	for _, name := range []string{"LICENSE", "LICENCE", "LICENSE.txt", "LICENCE.md", "LICENSE-APACHE", "LICENSE_MIT", "COPYING", "UNLICENSE"} {
		if !isLicenseFilename(name) {
			t.Errorf("isLicenseFilename(%q) = false", name)
		}
	}
}
