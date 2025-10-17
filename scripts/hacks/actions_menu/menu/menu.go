// Package menu provides the TUI model and rendering logic for the actions menu.
package menu

import (
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"strings"

	"actions_menu/actions"

	"github.com/charmbracelet/bubbles/list"
	"github.com/charmbracelet/bubbles/progress"
	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// Define cyberpunk-inspired colors
var (
	Purple = lipgloss.Color("#BD5CFF")
	Pink   = lipgloss.Color("#FF0087")
	Cyan   = lipgloss.Color("#00FFFF")
	Blue   = lipgloss.Color("#00AAFF")
	Black  = lipgloss.Color("#000000")
	White  = lipgloss.Color("#FFFFFF")
	Yellow = lipgloss.Color("#FFFF00")
)

// Styles for the TUI
var (
	titleStyle = lipgloss.NewStyle().
			Foreground(Pink).
			Bold(true).
			Background(Black).
			Padding(0, 1)
	itemStyle         = lipgloss.NewStyle().Foreground(Cyan).PaddingLeft(2)
	selectedItemStyle = lipgloss.NewStyle().Foreground(Purple).Bold(true).PaddingLeft(2)
	headerStyle       = lipgloss.NewStyle().Foreground(Yellow).Bold(true).Padding(1, 0, 0, 0)
	logStyle          = lipgloss.NewStyle().
				Foreground(White).
				Background(Black).
				Padding(1).
				Border(lipgloss.NormalBorder(), true).
				BorderForeground(Blue)
	progressStyle = lipgloss.NewStyle().Margin(1, 0)
)

const errorChanBuffer = 100

const (
	actionItemType = "action"
	optionItemType = "option"
	headerItemType = "header"
)

// actionItem implements list.Item
type actionItem struct {
	title, desc string
	selected    bool
	spec        *actions.ActionSpec // Pointer to the action spec, nil for non-action items like "yolo"
	itemType    string
}

func (i actionItem) Title() string       { return i.title }
func (i actionItem) Description() string { return i.desc }
func (i actionItem) FilterValue() string { return i.title }

// Custom delegate for rendering with checkbox
type customDelegate struct {
	list.DefaultDelegate
}

func (d customDelegate) Render(w io.Writer, m list.Model, index int, item list.Item) {
	var sb strings.Builder

	i, ok := item.(actionItem)
	if !ok {
		return
	}

	if i.itemType == headerItemType {
		sb.WriteString(headerStyle.Render(i.title))
		_, _ = fmt.Fprint(w, sb.String())
		return
	}

	check := "[ ]"
	if i.selected {
		check = "[x]"
	}

	if index == m.Index() {
		sb.WriteString(selectedItemStyle.Render(check + " " + i.title))
	} else {
		sb.WriteString(itemStyle.Render(check + " " + i.title))
	}

	if i.desc != "" {
		sb.WriteString("\n  " + i.desc)
	}

	_, _ = fmt.Fprint(w, sb.String())
}

// Model represents the state of the TUI application.
type Model struct {
	list       list.Model
	state      string
	total      int
	processed  int
	matched    int
	logs       *strings.Builder
	ch         chan tea.Msg
	spinner    spinner.Model
	progress   progress.Model
	logger     *log.Logger
	fileLogger *log.Logger
	doneScroll int
}

func listenForMsgs(ch chan tea.Msg) tea.Cmd {
	return func() tea.Msg {
		msg, ok := <-ch
		if !ok {
			// Channel closed, maybe handle this differently if needed
			return nil
		}
		return msg
	}
}

// InitialModel creates and returns the initial model for the TUI.
func InitialModel() Model {
	logFile := filepath.Join(os.TempDir(), "actions.log")
	_ = os.Remove(logFile) // Overwrite
	file, err := os.OpenFile(logFile, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0644)
	if err != nil {
		log.Fatalf("Failed to open log file: %v", err)
	}
	fileLogger := log.New(file, "", log.LstdFlags)
	fileLogger.Printf("App started")

	actionSpecs := actions.GetActions()
	items := make([]list.Item, 0, len(actionSpecs)+3)
	items = append(items, actionItem{title: "Actions", itemType: headerItemType})
	for _, spec := range actionSpecs {
		specCopy := spec
		items = append(
			items,
			actionItem{
				title:    spec.Title,
				desc:     spec.Description,
				spec:     &specCopy,
				itemType: actionItemType,
			},
		)
	}
	// Options section
	items = append(items, actionItem{title: "Options", itemType: headerItemType})
	items = append(
		items,
		actionItem{
			title:    "Apply changes (yolo)",
			desc:     "Actually modify the files instead of dry-run",
			itemType: optionItemType,
		},
	)

	delegate := customDelegate{list.NewDefaultDelegate()}

	l := list.New(items, delegate, 80, 24)
	l.Title = "Menu (space to toggle, enter to run selected action)"
	l.Styles.Title = titleStyle
	l.SetShowFilter(false)
	l.SetFilteringEnabled(false)
	l.SetShowHelp(true)
	l.KeyMap.NextPage.SetEnabled(false)
	l.KeyMap.GoToStart.SetEnabled(false)
	l.KeyMap.GoToEnd.SetEnabled(false)

	s := spinner.New()
	s.Spinner = spinner.Dot
	s.Style = lipgloss.NewStyle().Foreground(Pink)

	p := progress.New(progress.WithGradient(string(Blue), string(Pink)))

	logger := fileLogger

	return Model{
		list:       l,
		state:      "menu",
		total:      1000,
		logs:       &strings.Builder{},
		spinner:    s,
		progress:   p,
		logger:     logger,
		fileLogger: fileLogger,
		doneScroll: 0,
	}
}

// Init initialises the model.
func (m Model) Init() tea.Cmd {
	return nil
}

// Update handles incoming messages and updates the model accordingly.
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch m.state {

	case "menu":
		switch msg := msg.(type) {

		case tea.WindowSizeMsg:
			width := msg.Width
			height := msg.Height
			if width < 80 {
				width = 80
			}
			if height < 24 {
				height = 24
			}
			m.list.SetSize(width, height)
			return m, nil

		case tea.KeyMsg:
			switch msg.String() {
			case "q", "esc", "ctrl+c":
				return m, tea.Quit
			case " ":
				items := m.list.Items()
				idx := m.list.Index()
				if idx >= 0 && idx < len(items) {
					if ai, ok := items[idx].(actionItem); ok && ai.itemType != headerItemType {
						ai.selected = !ai.selected
						items[idx] = ai
						m.list.SetItems(items)
						m.fileLogger.Printf("Toggled %s to %t (via space key)", ai.title, ai.selected)
					}
				}
				return m, nil
			case "s":
				items := m.list.Items()
				idx := m.list.Index()
				if idx >= 0 && idx < len(items) {
					if ai, ok := items[idx].(actionItem); ok && ai.itemType != headerItemType {
						ai.selected = !ai.selected
						items[idx] = ai
						m.list.SetItems(items)
						fmt.Fprintf(m.logs, "Toggled %s to %t (via S key)\n", ai.title, ai.selected)
						m.fileLogger.Printf("Toggled %s to %t (via S key)", ai.title, ai.selected)
					}
				}
				return m, nil
			case "enter":
				m.logs.Reset()
				var selectedActions []*actions.ActionSpec
				yolo := false
				for _, item := range m.list.Items() {
					ai := item.(actionItem)
					if ai.selected {
						if ai.spec != nil {
							selectedActions = append(selectedActions, ai.spec)
							m.fileLogger.Printf("Selected action: %s", ai.title)
						}
						if ai.itemType == optionItemType && ai.title == "Apply changes (yolo)" {
							yolo = true
							m.fileLogger.Printf("Yolo mode enabled")
						}
					}
				}

				if len(selectedActions) == 0 {
					m.logs.WriteString("No action selected\n")
					m.fileLogger.Printf("Enter pressed with no actions selected")
					return m, nil
				}

				m.state = "running"
				m.fileLogger.Printf("Starting execution with %d actions", len(selectedActions))
				m.ch = make(chan tea.Msg, errorChanBuffer)

				for _, action := range selectedActions {
					go action.Action(m.ch, yolo, m.fileLogger)
				}
				return m, tea.Batch(m.spinner.Tick, listenForMsgs(m.ch))
			}
		}
		var cmd tea.Cmd
		m.list, cmd = m.list.Update(msg)
		return m, cmd

	case "running":
		switch msg := msg.(type) {
		case spinner.TickMsg:
			var cmd tea.Cmd
			m.spinner, cmd = m.spinner.Update(msg)
			return m, cmd
		case progress.FrameMsg:
			var cmd tea.Cmd
			newProgress, cmd := m.progress.Update(msg)
			m.progress = newProgress.(progress.Model)
			return m, cmd
		case actions.ProcessedMsg:
			m.processed++
			m.progress.SetPercent(float64(m.processed) / float64(m.total))
			return m, listenForMsgs(m.ch)
		case actions.MatchedMsg:
			m.matched++
			fmt.Fprintf(m.logs, "Found matching file: %s\n", string(msg))
			m.fileLogger.Printf("Processed file: %s", string(msg))
			return m, listenForMsgs(m.ch)
		case actions.DiffMsg:
			m.logs.WriteString("Would apply the following change:\n" + string(msg) + "\n")
			return m, listenForMsgs(m.ch)
		case actions.ErrorMsg:
			fmt.Fprintf(m.logs, "Error: %v\n", error(msg))
			m.fileLogger.Printf("Error: %v", error(msg))
			return m, listenForMsgs(m.ch)
		case tea.KeyMsg:
			if msg.String() == "ctrl+c" {
				m.fileLogger.Printf("User interrupted with Ctrl+C")
				return m, tea.Quit
			}
		case actions.DoneMsg:
			m.state = "done"
			m.fileLogger.Printf("Execution completed: %d processed, %d matched", m.processed, m.matched)
			return m, nil
		}

	case "done":
		switch msg := msg.(type) {
		case tea.KeyMsg:
			switch msg.String() {
			case "k", "up":
				if m.doneScroll > 0 {
					m.doneScroll--
				}
			case "j", "down":
				m.doneScroll++
			case "q", "esc", "ctrl+c":
				m.fileLogger.Printf("App exited by user")
				return m, tea.Quit
			default:
				m.fileLogger.Printf("App exited by user")
				return m, tea.Quit
			}
		}
	}

	return m, nil
}

// View renders the current state of the model as a string.
func (m Model) View() string {
	switch m.state {
	case "menu":
		view := m.list.View()
		if m.logs.Len() > 0 {
			view += "\n" + logStyle.Render(m.logs.String())
		}
		return view
	case "running":
		view := m.spinner.View() + " Processing files...\n"
		view += progressStyle.Render(m.progress.ViewAs(float64(m.processed) / float64(m.total)))
		view += fmt.Sprintf("\nProcessed: %d, Matched: %d\n", m.processed, m.matched)
		view += logStyle.Render(m.logs.String())
		return view
	case "done":
		view := "Operation completed!\n"
		view += fmt.Sprintf("Final: %d files processed, %d matched\n", m.processed, m.matched)
		lines := strings.Split(m.logs.String(), "\n")
		if m.doneScroll >= len(lines) {
			m.doneScroll = len(lines) - 1
		}
		if m.doneScroll < 0 {
			m.doneScroll = 0
		}
		start := m.doneScroll
		height := 20 // Fixed height for diff view; adjust as needed
		end := start + height
		if end > len(lines) {
			end = len(lines)
		}
		content := strings.Join(lines[start:end], "\n")
		view += "\nUse up/down to scroll diffs, press q to quit\n"
		view += logStyle.Render(content)
		return view
	}
	return ""
}
