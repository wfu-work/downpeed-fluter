package download

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"unicode"
)

// SafeFileName removes path separators and characters that are invalid on
// the supported desktop filesystems.
func SafeFileName(value string) string {
	value = strings.Map(func(character rune) rune {
		if unicode.IsControl(character) || strings.ContainsRune(`<>:"/\|?*`, character) {
			return '_'
		}
		return character
	}, value)
	value = strings.Trim(strings.TrimSpace(value), ".")
	if isWindowsReservedFileName(value) {
		return "_" + value
	}
	return value
}

func (m *Manager) ApplyFileConflictPolicy(policy FileConflictPolicy) {
	if _, err := validateFileConflictPolicy(policy); err != nil {
		return
	}
	m.mu.Lock()
	if !m.closed {
		m.fileConflictPolicy = policy
	}
	m.mu.Unlock()
}

func (m *Manager) selectHTTPDestination(directory, fileName string) (string, string, string, error) {
	m.mu.RLock()
	policy := m.fileConflictPolicy
	occupied := make(map[string]struct{})
	for _, task := range m.tasks {
		if !isTerminalState(task.State) {
			occupied[filepath.Clean(task.FilePath)] = struct{}{}
		}
	}
	m.mu.RUnlock()

	for copyNumber := 0; ; copyNumber++ {
		candidate := fileName
		if copyNumber > 0 {
			candidate = copyFileName(fileName, copyNumber)
		}
		destination := filepath.Join(directory, candidate)
		workPath := temporaryPath(destination)
		_, taskUsesDestination := occupied[filepath.Clean(destination)]
		destinationExists, err := pathExists(destination)
		if err != nil {
			return "", "", "", fmt.Errorf("%w: destination cannot be checked", ErrInvalidDestination)
		}
		workPathExists, err := pathExists(workPath)
		if err != nil {
			return "", "", "", fmt.Errorf("%w: temporary destination cannot be checked", ErrInvalidDestination)
		}
		if !taskUsesDestination && !destinationExists && !workPathExists {
			return candidate, destination, workPath, nil
		}
		if policy != FileConflictPolicyUniquify {
			return "", "", "", ErrDestinationExists
		}
	}
}

func copyFileName(fileName string, copyNumber int) string {
	extension := filepath.Ext(fileName)
	baseName := strings.TrimSuffix(fileName, extension)
	return fmt.Sprintf("%s (%d)%s", baseName, copyNumber, extension)
}

func pathExists(path string) (bool, error) {
	_, err := os.Lstat(path)
	if err == nil {
		return true, nil
	}
	if errors.Is(err, os.ErrNotExist) {
		return false, nil
	}
	return false, err
}

func isWindowsReservedFileName(value string) bool {
	base := strings.ToUpper(strings.SplitN(value, ".", 2)[0])
	switch base {
	case "CON", "PRN", "AUX", "NUL":
		return true
	}
	if len(base) != 4 || (base[:3] != "COM" && base[:3] != "LPT") {
		return false
	}
	return base[3] >= '1' && base[3] <= '9'
}
