package main

import (
	"fmt"
	"regexp"
	"slices"
	"strings"
	"time"

	"github.com/charmbracelet/lipgloss"
)

const (
	colorDirectory = "#6c7086"
	colorMuted     = "#9399b2"
	colorAgent     = "#a6e3a1"
	colorFavorite  = "#f9e2af"
	colorAttached  = "#89b4fa"
	colorPointer   = "#b4befe"
	colorSelection = "#313244"
	colorMatch     = "#fab387"
	colorBorder    = "#45475a"
	colorWarning   = "#f38ba8"
)

var hexColor = regexp.MustCompile(`^#[0-9A-Fa-f]{6}$`)

func fg(color string) lipgloss.Style {
	style := lipgloss.NewStyle()
	if hexColor.MatchString(color) {
		style = style.Foreground(lipgloss.Color(color))
	}
	return style
}

func paint(color, text string) string {
	return fg(color).Render(text)
}

func relativeAge(timestamp int64, now time.Time) string {
	if timestamp <= 0 {
		return ""
	}
	seconds := max(0, now.Unix()-timestamp)
	switch {
	case seconds < 60:
		return "now"
	case seconds < 3600:
		return fmt.Sprintf("%dm", seconds/60)
	case seconds < 48*3600:
		return fmt.Sprintf("%dh", seconds/3600)
	}
	return fmt.Sprintf("%dd", seconds/86400)
}

func plural(count int, noun string) string {
	if count == 1 {
		return fmt.Sprintf("%d %s", count, noun)
	}
	return fmt.Sprintf("%d %ss", count, noun)
}

func previewField(label, value string) string {
	return paint(colorDirectory, fmt.Sprintf("%-9s", label)) + value
}

func previewTitle(row Row, kind string) []string {
	star := ""
	if row.Favorite {
		star = paint(colorFavorite, "★ ")
	}
	return []string{
		star + fg(row.Color).Bold(true).Render(row.Name),
		paint(colorMuted, kind) + "  " + paint(row.Color, row.Host),
	}
}

func staleNote(row Row) []string {
	switch row.Status {
	case statusOffline:
		return []string{"", paint(colorWarning, row.Host+" is unreachable; showing cached details")}
	case statusConnecting:
		return []string{"", paint(colorMuted, "fetching "+row.Host+"…")}
	}
	return nil
}

func previewLines(row Row, now time.Time) []string {
	if row.Session {
		return sessionPreview(row, now)
	}
	return directoryPreview(row)
}

func sessionPreview(row Row, now time.Time) []string {
	lines := previewTitle(row, "session")
	lines = append(lines, "")
	if row.Path != "" {
		lines = append(lines, previewField("path", abbreviatePath(row.Path)))
	}
	if !row.HasPanes {
		lines = append(lines, previewField("windows", row.Windows))
		lines = append(lines, "", paint(colorMuted, row.Host+" sent no pane details; it may run an older sessionizer"))
		return append(lines, staleNote(row)...)
	}
	windows := map[string]bool{}
	var agents []string
	for _, pane := range row.Panes {
		windows[pane.WindowIndex] = true
		for _, agent := range pane.Agents {
			if !slices.Contains(agents, agent) {
				agents = append(agents, agent)
			}
		}
	}
	lines = append(lines, previewField("layout", plural(len(windows), "window")+", "+plural(len(row.Panes), "pane")))
	if age := relativeAge(row.Recency, now); age == "now" {
		lines = append(lines, previewField("visited", "just now"))
	} else if age != "" {
		lines = append(lines, previewField("visited", age+" ago"))
	}
	if len(agents) > 0 {
		lines = append(lines, previewField("agents", paint(colorAgent, strings.Join(agents, ", "))))
	}
	if row.Current {
		lines = append(lines, previewField("status", paint(colorAttached, "here")))
	} else if row.Attached {
		lines = append(lines, previewField("status", paint(colorAttached, "attached")))
	}
	lines = append(lines, staleNote(row)...)

	previousWindow := "\x00"
	for _, pane := range row.Panes {
		if pane.WindowIndex != previousWindow {
			lines = append(lines, "")
			label := pane.WindowIndex + "  " + pane.WindowName
			if pane.WindowActive {
				lines = append(lines, paint(row.Color, "●")+" "+lipgloss.NewStyle().Bold(true).Render(label))
			} else {
				lines = append(lines, paint(colorDirectory, "○")+" "+label)
			}
			previousWindow = pane.WindowIndex
		}
		marker := " "
		if pane.PaneActive {
			marker = paint(row.Color, "▎")
		}
		command := sanitize(pane.Command)
		if command == "" {
			command = "shell"
		}
		line := "  " + marker + " " + command
		if len(pane.Agents) > 0 {
			line += "  " + paint(colorAgent, strings.Join(pane.Agents, " "))
		}
		if path := abbreviatePath(sanitize(pane.Path)); path != "" {
			line += "  " + paint(colorDirectory, path)
		}
		lines = append(lines, line)
	}
	if !row.Local {
		lines = append(lines, "", paint(colorDirectory, "M-s opens this picker · prefix d leaves "+row.Host))
	}
	return lines
}

func directoryPreview(row Row) []string {
	lines := previewTitle(row, "new session")
	lines = append(lines, "", previewField("path", abbreviatePath(row.Target)))
	summary := row.Summary
	if summary == nil {
		if row.Local {
			lines = append(lines, paint(colorMuted, "cannot read this directory"))
		} else {
			lines = append(lines, "", paint(colorMuted, row.Host+" sent no listing; it may run an older sessionizer"))
		}
		return append(lines, staleNote(row)...)
	}
	return append(lines, summaryLines(summary)...)
}

func summaryLines(summary *DirSummary) []string {
	var lines []string
	if summary.Branch != "" {
		lines = append(lines, previewField("branch", summary.Branch))
	}
	contents := plural(summary.Visible, "item")
	if summary.Hidden > 0 {
		contents += fmt.Sprintf(", %d hidden", summary.Hidden)
	}
	lines = append(lines, previewField("contents", contents), "")
	for _, entry := range summary.Entries {
		if entry.Dir {
			lines = append(lines, paint(colorAttached, entry.Name+"/"))
		} else {
			lines = append(lines, entry.Name)
		}
	}
	if more := summary.Visible - len(summary.Entries); more > 0 {
		lines = append(lines, paint(colorDirectory, fmt.Sprintf("… %d more", more)))
	}
	return lines
}

func sanitize(value string) string {
	return strings.NewReplacer("\t", " ", "\n", " ", "\r", " ").Replace(value)
}
