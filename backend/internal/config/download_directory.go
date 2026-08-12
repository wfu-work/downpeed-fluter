package config

import (
	"bufio"
	"os"
	"path/filepath"
	"runtime"
	"strings"
)

func defaultDownloadDirectory(userHomeDir string) string {
	if runtime.GOOS == "linux" {
		if directory := linuxDownloadDirectory(userHomeDir); directory != "" {
			return directory
		}
	}
	return systemDownloadDirectory(filepath.Join(userHomeDir, "Downloads"))
}

func linuxDownloadDirectory(userHomeDir string) string {
	configHome := strings.TrimSpace(os.Getenv("XDG_CONFIG_HOME"))
	if configHome == "" {
		configHome = filepath.Join(userHomeDir, ".config")
	}
	file, err := os.Open(filepath.Join(configHome, "user-dirs.dirs"))
	if err != nil {
		return ""
	}
	defer file.Close()
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if !strings.HasPrefix(line, "XDG_DOWNLOAD_DIR=") {
			continue
		}
		value := strings.TrimSpace(strings.TrimPrefix(line, "XDG_DOWNLOAD_DIR="))
		value = strings.Trim(value, `"`)
		value = strings.Replace(value, "$HOME", userHomeDir, 1)
		if filepath.IsAbs(value) {
			return filepath.Clean(value)
		}
	}
	return ""
}
