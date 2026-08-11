package download

import (
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
