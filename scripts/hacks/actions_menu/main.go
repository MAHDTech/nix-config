// Package main is the entry point for the actions_menu program.
package main

import (
	"fmt"
	"os"

	_ "actions_menu/actions" // Anonymous import to trigger action registration
	"actions_menu/menu"

	tea "github.com/charmbracelet/bubbletea"
)

func main() {
	p := tea.NewProgram(menu.InitialModel(), tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Println("Error running program:", err)
		os.Exit(1)
	}
}
