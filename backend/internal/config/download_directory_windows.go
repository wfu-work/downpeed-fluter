//go:build windows

package config

import "golang.org/x/sys/windows"

func systemDownloadDirectory(fallback string) string {
	directory, err := windows.KnownFolderPath(windows.FOLDERID_Downloads, windows.KF_FLAG_DEFAULT)
	if err != nil || directory == "" {
		return fallback
	}
	return directory
}
