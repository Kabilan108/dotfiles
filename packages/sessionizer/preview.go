package main

import (
	"fmt"
	"strconv"
	"strings"
	"time"
	"unicode"

	"github.com/charmbracelet/x/ansi"
)

// previewContext is what the preview needs beyond the row: the time, the
// column's width, and the state of the row's host.
type previewContext struct {
	now     time.Time
	width   int
	pending bool
	updated int64
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

func ago(timestamp int64, now time.Time) string {
	switch age := relativeAge(timestamp, now); age {
	case "":
		return ""
	case "now":
		return "just now"
	default:
		return age + " ago"
	}
}

func previewField(icon, label, value string) string {
	return paint(colorOverlay0, icon+" "+fmt.Sprintf("%-9s", label)) + value
}

func previewHeading(title, detail string) string {
	return paint(colorOverlay1, title+" ") + paint(colorOverlay0, detail)
}

func hostLabel(host, color string) string {
	return paint(color, hostIcon(host)+" "+host)
}

func hostNotes(row Row, ctx previewContext) []string {
	var notes []string
	if row.Status == statusOffline {
		reported := "showing cached details"
		if since := ago(ctx.updated, ctx.now); since != "" {
			reported = "showing what it reported " + since
		}
		notes = append(notes, paint(colorRed, iconOffline+" "+row.Host+" unreachable · "+reported))
	}
	if ctx.pending {
		notes = append(notes, paint(colorPeach, iconRefresh+" refreshing "+row.Host+"…"))
	}
	return notes
}

// previewLines renders the preview for row and the hint pinned under it.
func previewLines(row Row, ctx previewContext) ([]string, string) {
	if row.Session {
		return sessionPreview(row, ctx)
	}
	return directoryPreview(row, ctx)
}

func sessionPreview(row Row, ctx previewContext) ([]string, string) {
	title := bold(sanitize(row.Name))
	if row.Favorite {
		title = paint(colorYellow, iconStar+" ") + title
	}
	subtitle := hostLabel(row.Host, row.Color) + paint(colorOverlay1, " · session")
	if row.Current {
		subtitle += paint(colorLavender, " · here")
	} else if row.Attached {
		subtitle += paint(colorBlue, " · attached")
	}
	lines := append([]string{title, subtitle}, hostNotes(row, ctx)...)
	lines = append(lines, "")
	if row.Path != "" {
		lines = append(lines, previewField(iconFolder, "path", abbreviatePath(sanitize(row.Path))))
	}
	if row.Branch != "" {
		lines = append(lines, previewField(iconBranch, "branch", paint(colorMauve, sanitize(row.Branch))))
	}
	if visited := ago(row.Recency, ctx.now); visited != "" {
		if created := ago(row.Created, ctx.now); created != "" {
			visited += paint(colorOverlay0, " · created "+created)
		}
		lines = append(lines, previewField(iconClock, "visited", visited))
	}
	if agents := uniqueAgents(row.Panes); len(agents) > 0 {
		names := make([]string, len(agents))
		for i, agent := range agents {
			names[i] = paint(agentColor(agent), sanitize(agent))
		}
		lines = append(lines, previewField(iconAgent, "agents", strings.Join(names, ", ")))
	}
	lines = append(lines, "")
	if row.HasPanes {
		lines = append(lines, previewHeading("WINDOWS", strconv.Itoa(windowCount(row.Panes))))
		lines = append(lines, windowLines(row.Panes)...)
	} else {
		lines = append(lines, previewHeading("WINDOWS", sanitize(row.Windows)),
			paint(colorOverlay1, row.Host+" sent no pane details; it may run an older sessionizer"))
	}
	hint := "enter switches here"
	if !row.Local {
		hint = "enter opens it through the " + row.Host + " proxy"
	}
	return lines, paint(colorOverlay0, hint)
}

func windowCount(panes []Pane) int {
	count := 0
	previous := "\x00"
	for _, pane := range panes {
		if pane.WindowIndex != previous {
			count++
			previous = pane.WindowIndex
		}
	}
	return count
}

// windowLines draws a session's windows as a tree: one line per window with
// its first pane, then a └ line for each other pane.
func windowLines(panes []Pane) []string {
	var lines []string
	previous := "\x00"
	for _, pane := range panes {
		if pane.WindowIndex == previous {
			lines = append(lines, strings.Repeat(" ", 14)+paint(colorSurface2, "└ ")+paneText(pane))
			continue
		}
		previous = pane.WindowIndex
		marker := "  "
		name := fit(pane.WindowName, 8) + " "
		if pane.WindowActive {
			marker = paint(colorLavender, "▸ ")
			name = bold(name)
		}
		lines = append(lines, marker+paint(colorOverlay1, fit(pane.WindowIndex, 2)+" ")+name+paneText(pane))
	}
	return lines
}

func paneText(pane Pane) string {
	var label string
	switch command := sanitize(pane.Command); {
	case len(pane.Agents) > 0:
		names := make([]string, len(pane.Agents))
		for i, agent := range pane.Agents {
			names[i] = paint(agentColor(agent), sanitize(agent))
		}
		label = paint(agentColor(pane.Agents[0]), iconAgent) + " " + strings.Join(names, " ")
	case command == "nvim" || command == "vim":
		label = paint(colorGreen, iconVim) + " " + command
	case command == "node":
		label = paint(colorGreen, iconNode) + " " + command
	case command == "":
		label = paint(colorOverlay2, iconTerminal) + " shell"
	default:
		label = paint(colorOverlay2, iconTerminal) + " " + command
	}
	if path := abbreviatePath(sanitize(pane.Path)); path != "" {
		label += "  " + paint(colorOverlay0, path)
	}
	return label
}

func directoryPreview(row Row, ctx previewContext) ([]string, string) {
	icon := iconFolder
	if row.Git {
		icon = iconGit
	}
	title := paint(colorOverlay2, icon+" ") + bold(sanitize(row.Name))
	if row.Favorite {
		title = paint(colorYellow, iconStar+" ") + title
	}
	subtitle := hostLabel(row.Host, row.Color) + paint(colorOverlay1, " · directory")
	if row.Git {
		subtitle += paint(colorOverlay1, " · git")
	}
	lines := append([]string{title, subtitle}, hostNotes(row, ctx)...)
	lines = append(lines, "", previewField(iconFolder, "path", abbreviatePath(sanitize(row.Target))))
	hint := paint(colorOverlay0, "enter creates session "+directorySessionName(row.Target)+" on "+row.Host)
	summary := row.Summary
	if summary == nil {
		if row.Local {
			lines = append(lines, "", paint(colorOverlay1, "cannot read this directory"))
		} else {
			lines = append(lines, "", paint(colorOverlay1, row.Host+" sent no listing; it may run an older sessionizer"))
		}
		return lines, hint
	}
	return append(lines, summaryLines(summary, ctx)...), hint
}

// directorySessionName is the name a new session for path usually gets;
// sessionNameForDirectory adds the parent's name when that one is taken.
func directorySessionName(path string) string {
	path = strings.TrimRight(path, "/")
	name := path[strings.LastIndex(path, "/")+1:]
	name = unsafeSessionChars.ReplaceAllString(sanitize(name), "_")
	if name == "" {
		return "shell"
	}
	return name
}

func summaryLines(summary *DirSummary, ctx previewContext) []string {
	var lines []string
	if summary.Branch != "" {
		branch := paint(colorMauve, sanitize(summary.Branch))
		if git := summary.Git; git != nil {
			if git.Dirty > 0 {
				branch += paint(colorPeach, fmt.Sprintf(" · %d modified", git.Dirty))
			} else {
				branch += paint(colorGreen, " · clean")
			}
			if git.Ahead > 0 {
				branch += paint(colorOverlay1, fmt.Sprintf(" · %d ahead", git.Ahead))
			}
			if git.Behind > 0 {
				branch += paint(colorOverlay1, fmt.Sprintf(" · %d behind", git.Behind))
			}
		}
		lines = append(lines, previewField(iconBranch, "branch", branch))
	}
	if git := summary.Git; git != nil && git.Commit != "" {
		commit := paint(colorYellow, sanitize(git.Commit)) + " " + sanitize(git.Subject)
		if when := ago(git.Time, ctx.now); when != "" {
			commit += paint(colorOverlay0, " · "+when)
		}
		lines = append(lines, previewField(iconCommit, "commit", commit))
	}
	if summary.Readme != "" {
		lines = append(lines, previewField(iconReadme, "readme", paint(colorSubtext, sanitize(summary.Readme))))
	}
	contents := strconv.Itoa(summary.Visible)
	if summary.Hidden > 0 {
		contents += fmt.Sprintf(" · %d hidden", summary.Hidden)
	}
	lines = append(lines, "", previewHeading("CONTENTS", contents))
	lines = append(lines, entryColumns(summary.Entries, ctx.width)...)
	if more := summary.Visible - len(summary.Entries); more > 0 {
		lines = append(lines, paint(colorOverlay0, fmt.Sprintf("… %d more", more)))
	}
	return lines
}

// entryColumns lays out directory entries row by row in as many columns as
// the preview fits.
func entryColumns(entries []DirEntry, width int) []string {
	if len(entries) == 0 {
		return nil
	}
	widest := 0
	for _, entry := range entries {
		widest = max(widest, ansi.StringWidth(sanitize(entry.Name))+3)
	}
	columnWidth := max(10, min(widest+1, 28))
	columns := max(1, width/columnWidth)
	var lines []string
	for start := 0; start < len(entries); start += columns {
		var line strings.Builder
		for _, entry := range entries[start:min(start+columns, len(entries))] {
			line.WriteString(entryCell(entry, columnWidth))
		}
		lines = append(lines, line.String())
	}
	return lines
}

func entryCell(entry DirEntry, width int) string {
	if entry.Dir {
		return paint(colorBlue, fit(iconFolder+" "+entry.Name+"/", width-1)+" ")
	}
	icon := iconFile
	if strings.HasPrefix(strings.ToLower(entry.Name), "readme") {
		icon = iconReadme
	}
	return paint(colorText, fit(icon+" "+entry.Name, width-1)+" ")
}

// sanitize drops control characters, which would break the layout.
func sanitize(value string) string {
	return strings.Map(func(r rune) rune {
		if unicode.IsControl(r) {
			return ' '
		}
		return r
	}, value)
}
