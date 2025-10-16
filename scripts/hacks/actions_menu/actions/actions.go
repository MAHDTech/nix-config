// Package actions provides types and functions for handling TUI messages and registering actions.
package actions

import (
	"log"

	tea "github.com/charmbracelet/bubbletea"
)

// ProcessedMsg is a message indicating that a file has been processed.
type ProcessedMsg struct{}

// MatchedMsg contains the path of a file that matched the criteria.
type MatchedMsg string

// DiffMsg contains the diff output for a file change.
type DiffMsg string

// ErrorMsg wraps an error that occurred during processing.
type ErrorMsg error

// DoneMsg signals the completion of an action.
type DoneMsg struct{}

// ActionSpec defines the contract for an action that can be run from the menu.
type ActionSpec struct {
	Title       string
	Description string
	Action      func(ch chan tea.Msg, yolo bool, logger *log.Logger)
}

var registeredActions []ActionSpec

// Register adds an action to the list of available actions.
func Register(spec ActionSpec) {
	registeredActions = append(registeredActions, spec)
}

// GetActions returns the list of registered actions.
func GetActions() []ActionSpec {
	return registeredActions
}
