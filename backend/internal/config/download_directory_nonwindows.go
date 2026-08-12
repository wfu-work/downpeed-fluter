//go:build !windows

package config

func systemDownloadDirectory(fallback string) string {
	return fallback
}
