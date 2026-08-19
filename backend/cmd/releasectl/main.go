package main

import (
	"context"
	"flag"
	"fmt"
	"os"

	"github.com/wfu-work/downpeed-fluter/backend/internal/releaseartifact"
)

func main() {
	if len(os.Args) < 2 {
		fail("usage: releasectl <notices|manifest|verify> [flags]")
	}
	var err error
	switch os.Args[1] {
	case "notices":
		err = generateNotices(os.Args[2:])
	case "manifest":
		err = generateManifest(os.Args[2:])
	case "verify":
		err = verifyRelease(os.Args[2:])
	default:
		fail("unknown releasectl command %q", os.Args[1])
	}
	if err != nil {
		fail("%v", err)
	}
}

func generateNotices(arguments []string) error {
	flags := flag.NewFlagSet("notices", flag.ContinueOnError)
	repositoryRoot := flags.String("repo-root", "..", "repository root")
	output := flags.String("output", "", "output file")
	if err := flags.Parse(arguments); err != nil {
		return err
	}
	return releaseartifact.GenerateNotices(context.Background(), releaseartifact.NoticeConfig{
		RepositoryRoot: *repositoryRoot,
		OutputPath:     *output,
	})
}

func generateManifest(arguments []string) error {
	flags := flag.NewFlagSet("manifest", flag.ContinueOnError)
	config := releaseartifact.ManifestConfig{}
	flags.StringVar(&config.Product, "product", "Downpeed", "product name")
	flags.StringVar(&config.Version, "version", "", "release version")
	flags.StringVar(&config.BuildNumber, "build-number", "", "build number")
	flags.StringVar(&config.Commit, "commit", "", "source commit")
	flags.StringVar(&config.BuildDate, "build-date", "", "RFC3339 build date")
	flags.StringVar(&config.Channel, "channel", "", "release channel")
	flags.StringVar(&config.Platform, "platform", "", "target platform")
	flags.StringVar(&config.Architecture, "arch", "", "target architecture")
	flags.StringVar(&config.Signing, "signing", "", "signing mode")
	flags.StringVar(&config.ArtifactPath, "artifact", "", "release artifact")
	flags.StringVar(&config.NoticesPath, "notices", "", "third-party notices")
	flags.StringVar(&config.ManifestPath, "output", "", "manifest output")
	flags.StringVar(&config.ChecksumsPath, "checksums", "", "checksums output")
	if err := flags.Parse(arguments); err != nil {
		return err
	}
	return releaseartifact.WriteManifest(config)
}

func verifyRelease(arguments []string) error {
	flags := flag.NewFlagSet("verify", flag.ContinueOnError)
	manifest := flags.String("manifest", "", "release manifest")
	checksums := flags.String("checksums", "", "release checksums")
	if err := flags.Parse(arguments); err != nil {
		return err
	}
	return releaseartifact.VerifyManifest(*manifest, *checksums)
}

func fail(format string, arguments ...any) {
	fmt.Fprintf(os.Stderr, "releasectl: "+format+"\n", arguments...)
	os.Exit(1)
}
