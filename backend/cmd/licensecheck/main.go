package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"github.com/wfu-work/downpeed-fluter/backend/internal/compliance"
)

func main() {
	var (
		mode        = flag.String("mode", "candidate", "candidate verifies review evidence; release also verifies the compiled dependency graph")
		policyPath  = flag.String("policy", "../docs/licenses/bt-dependency-policy.json", "path to the BT dependency policy")
		backendPath = flag.String("backend", ".", "path to the backend Go module")
		moduleCache = flag.String("module-cache", "", "Go module cache; defaults to go env GOMODCACHE")
	)
	flag.Parse()

	policy, err := compliance.LoadPolicy(*policyPath)
	exitOnError(err)
	if *moduleCache == "" {
		*moduleCache, err = goModuleCache()
		exitOnError(err)
	}
	exitOnError(compliance.VerifyCandidate(policy, *moduleCache))

	switch *mode {
	case "candidate":
		fmt.Printf("verified candidate %s@%s (%s)\n", policy.Component.ModulePath, policy.Component.Version, policy.Component.License)
	case "release":
		exitOnError(compliance.VerifyPinnedModule(
			policy,
			filepath.Join(*backendPath, "go.mod"),
			filepath.Join(*backendPath, "go.sum"),
		))
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
		defer cancel()
		modules, err := compliance.ListBuildModules(ctx, *backendPath)
		exitOnError(err)
		report, err := compliance.VerifyBuildLicenses(policy, modules)
		exitOnError(err)
		for _, item := range report {
			fmt.Printf("%s@%s: %v\n", item.Module.Path, item.Module.Version, item.Licenses)
		}
		fmt.Printf("verified %d compiled third-party modules\n", len(report))
	default:
		exitOnError(fmt.Errorf("unsupported mode %q", *mode))
	}
}

func goModuleCache() (string, error) {
	command := exec.Command("go", "env", "GOMODCACHE")
	output, err := command.Output()
	if err != nil {
		return "", fmt.Errorf("resolve GOMODCACHE: %w", err)
	}
	return stringTrimSpace(output), nil
}

func stringTrimSpace(value []byte) string {
	start, end := 0, len(value)
	for start < end && (value[start] == ' ' || value[start] == '\n' || value[start] == '\r' || value[start] == '\t') {
		start++
	}
	for end > start && (value[end-1] == ' ' || value[end-1] == '\n' || value[end-1] == '\r' || value[end-1] == '\t') {
		end--
	}
	return string(value[start:end])
}

func exitOnError(err error) {
	if err == nil {
		return
	}
	fmt.Fprintln(os.Stderr, "licensecheck:", err)
	os.Exit(1)
}
