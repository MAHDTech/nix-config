// Package utils provides utility functions for file processing and diff generation.
package utils

import (
	"fmt"
	"log"
	"os"
	"regexp"
	"strings"
)

// ProcessFile processes a devenv.nix file by removing excludes from git-hooks or pre-commit sections.
// It returns whether the file changed, a diff string (if not applying changes), and any error.
func ProcessFile(
	path string,
	yolo bool,
	logger *log.Logger,
) (changed bool, diffStr string, err error) {
	logger.Printf("Processing file: %s", path)
	info, err := os.Stat(path)
	if err != nil {
		logger.Printf("Error stating file %s: %v", path, err)
		return false, "", fmt.Errorf("error stating file: %w", err)
	}

	content, err := os.ReadFile(path)
	if err != nil {
		logger.Printf("Error reading file %s: %v", path, err)
		return false, "", fmt.Errorf("error reading file: %w", err)
	}

	originalContent := string(content)
	// Check for git-hooks pattern
	pattern1 := regexp.MustCompile(`(?s)(git-hooks\s*=\s*{\s*excludes\s*=\s*\[).*?(\];)`)
	matched1 := pattern1.MatchString(originalContent)
	// Check for pre-commit pattern
	pattern2 := regexp.MustCompile(`(?s)(pre-commit\s*=\s*{\s*excludes\s*=\s*\[).*?(\];)`)
	matched2 := pattern2.MatchString(originalContent)
	if matched1 {
		logger.Printf("Git-hooks pattern matched in %s", path)
	} else if matched2 {
		logger.Printf("Pre-commit pattern matched in %s", path)
	} else {
		logger.Printf("No pattern matched in %s", path)
	}
	newContent := originalContent
	if matched1 {
		newContent = pattern1.ReplaceAllString(newContent, `git-hooks = { excludes = []; `)
	}
	if matched2 {
		newContent = pattern2.ReplaceAllString(newContent, `pre-commit = { excludes = []; `)
	}

	if originalContent == newContent {
		logger.Printf("File %s unchanged", path)
		return false, "", nil
	}

	changed = true

	if !yolo {
		logger.Printf("File %s changed, generating diff", path)
		dLines, err := Diff(originalContent, newContent, path)
		if err != nil {
			logger.Printf("Error generating diff for %s: %v", path, err)
			return changed, "", fmt.Errorf("error generating diff: %w", err)
		}
		diffStr = strings.Join(dLines, "")
		return changed, diffStr, nil
	}

	// Apply
	logger.Printf("Applying changes to file %s", path)
	backupPath := path + ".bak"
	if err := os.WriteFile(backupPath, content, info.Mode()); err != nil {
		logger.Printf("Error creating backup for %s: %v", path, err)
		return changed, "", fmt.Errorf("error creating backup: %w", err)
	}

	if err := os.WriteFile(path, []byte(newContent), info.Mode()); err != nil {
		logger.Printf("Error writing file %s: %v", path, err)
		if errRestore := os.Rename(backupPath, path); errRestore != nil {
			logger.Printf("Error restoring backup for %s: %v", path, errRestore)
		}
		return changed, "", fmt.Errorf("error writing file: %w", err)
	}

	if err := os.Remove(backupPath); err != nil {
		logger.Printf("Error removing backup %s: %v", backupPath, err)
	}

	logger.Printf("File %s processed successfully", path)
	return changed, "", nil
}

// Diff computes the difference between original and modified content as a list of diff lines.
func Diff(original, modified, path string) ([]string, error) {
	var result []string
	origLines, err := SplitLines(original)
	if err != nil {
		return nil, fmt.Errorf("error splitting original content: %w", err)
	}
	modLines, err := SplitLines(modified)
	if err != nil {
		return nil, fmt.Errorf("error splitting modified content: %w", err)
	}

	for i := 0; i < len(origLines) || i < len(modLines); i++ {
		if i >= len(origLines) {
			result = append(result, "+"+modLines[i])
		} else if i >= len(modLines) {
			result = append(result, "-"+origLines[i])
		} else if origLines[i] != modLines[i] {
			result = append(result, "-"+origLines[i])
			result = append(result, "+"+modLines[i])
		}
	}

	if len(result) > 0 {
		result = append([]string{
			fmt.Sprintf("--- %s", path),
			fmt.Sprintf("+++ %s (modified)", path),
		}, result...)
		// Cap diff to 25 lines max (2 headers + 25 diff lines)
		if len(result) > 27 {
			result = result[:27]
			result = append(result, "... (diff truncated after 25 lines)")
		}
	}

	return result, nil
}

// SplitLines splits a string into a slice of lines.
func SplitLines(s string) ([]string, error) {
	var lines []string
	start := 0
	for i, r := range s {
		if r == '\n' {
			lines = append(lines, s[start:i+1])
			start = i + 1
		}
	}
	if start < len(s) {
		lines = append(lines, s[start:])
	}
	return lines, nil
}
