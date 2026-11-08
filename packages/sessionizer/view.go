package main

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/x/ansi"
)

// minNameWidth is how narrow a row's name gets before its agents give way.
const minNameWidth = 12

type segment struct {
	color string
	text  string
	bold  bool
}

func segmentsWidth(segments []segment) int {
	width := 0
	for _, part := range segments {
		width += ansi.StringWidth(part.text)
	}
	return width
}

// renderSegments draws segments on background, cut or padded to width.
func renderSegments(segments []segment, width int, background lipgloss.Style) string {
	var out strings.Builder
	used := 0
	for _, part := range segments {
		remaining := width - used
		if remaining <= 0 {
			break
		}
		text := part.text
		if ansi.StringWidth(text) > remaining {
			text = ansi.Truncate(text, remaining, "…")
		}
		style := background
		if hexColor.MatchString(part.color) {
			style = style.Foreground(lipgloss.Color(part.color))
		}
		if part.bold {
			style = style.Bold(true)
		}
		out.WriteString(style.Render(text))
		used += ansi.StringWidth(text)
	}
	if used < width {
		out.WriteString(background.Render(strings.Repeat(" ", width-used)))
	}
	return out.String()
}

func (m *pickerModel) View() string {
	if m.width == 0 || m.height == 0 {
		return ""
	}
	listWidth, previewWidth := m.columns()
	rule := paint(colorSurface1, strings.Repeat("─", m.width))
	lines := []string{m.chipLine(m.width), m.promptLine(m.width), rule}
	list := m.listLines(listWidth - 1)
	var preview []string
	if previewWidth > 0 {
		preview = m.previewColumn(previewWidth)
	}
	for i := range m.listHeight() {
		line := ""
		if i < len(list) {
			line = list[i]
		}
		line = padTo(line, listWidth)
		if previewWidth > 0 {
			line += preview[i]
		}
		lines = append(lines, line)
	}
	lines = append(lines, rule, m.footerLine(m.width))
	if len(lines) > m.height {
		lines = lines[:m.height]
	}
	for i := range lines {
		lines[i] = padTo(lines[i], m.width)
	}
	return strings.Join(lines, "\n")
}

// chipLine shows ALL and each machine with its row count; the machine
// filter's chip is lit. Remote machines show when they are refreshing or
// offline.
func (m *pickerModel) chipLine(width int) string {
	total := 0
	for _, count := range m.hostCounts {
		total += count
	}
	var chips []string
	for i, machine := range m.machines {
		var label []segment
		count := total
		if machine == "" {
			label = []segment{{text: "ALL"}}
		} else {
			count = m.hostCounts[machine]
			label = []segment{{color: m.colors[machine], text: hostIcon(machine) + " " + machine}}
			if state, ok := m.hostState(machine); ok {
				if state.status == statusOffline {
					label = append(label, segment{color: colorRed, text: " " + iconOffline})
				}
				if state.pending {
					label = append(label, segment{color: colorPeach, text: " " + iconRefresh})
				}
			}
		}
		chip := append([]segment{{text: " "}}, label...)
		chip = append(chip, segment{color: colorOverlay1, text: " " + strconv.Itoa(count) + " "})
		background := lipgloss.NewStyle()
		if i == m.machine {
			background = background.Background(lipgloss.Color(colorSurface1))
		}
		chips = append(chips, renderSegments(chip, segmentsWidth(chip), background))
	}
	return truncate(strings.Join(chips, ""), width)
}

func (m *pickerModel) promptLine(width int) string {
	label := paint(colorOverlay1, "insert> ")
	if m.normal {
		label = paint(colorPeach, "normal> ")
	}
	prompt := paint(colorLavender, iconSearch+" ") + label + sanitize(string(m.query))
	if !m.normal {
		prompt += lipgloss.NewStyle().Background(lipgloss.Color(colorLavender)).Render(" ")
	}
	info := paint(colorOverlay1, fmt.Sprintf("%d/%d", len(m.visible), len(m.rows)))
	switch m.kind {
	case kindSessions:
		info = paint(colorMauve, "sessions only") + "  " + info
	case kindDirectories:
		info = paint(colorMauve, "directories only") + "  " + info
	}
	gap := width - ansi.StringWidth(prompt) - ansi.StringWidth(info) - 1
	if gap < 1 {
		return truncate(prompt, width)
	}
	return prompt + strings.Repeat(" ", gap) + info
}

func (m *pickerModel) footerLine(width int) string {
	if m.message != "" {
		return truncate(paint(colorRed, m.message), width)
	}
	hint := "enter open · tab machine · ^s kind · ^f favorite · esc normal"
	if m.normal {
		hint = "enter open · j/k move · g/G ends · f favorite · s kind · i insert · q quit"
	}
	return truncate(paint(colorOverlay0, hint), width)
}

func (m *pickerModel) listLines(width int) []string {
	terms := parseQuery(string(m.query))
	first, end := m.shownItems()
	var lines []string
	for _, item := range m.items[first:end] {
		if item.header() {
			lines = append(lines, sectionLine(item, width))
			continue
		}
		row := m.rows[m.visible[item.row]]
		top, bottom := m.rowLines(row, item.row == m.cursor, terms, width)
		lines = append(lines, top, bottom)
	}
	if len(lines) == 0 && first < len(m.items) {
		lines = append(lines, sectionLine(m.items[first], width))
	}
	return lines
}

func sectionLine(item listItem, width int) string {
	if !item.header() {
		return ""
	}
	label := paint(colorOverlay0, sectionTitles[item.section]+" ") + paint(colorSurface2, strconv.Itoa(item.count)) + " "
	rule := max(0, width-ansi.StringWidth(label))
	return label + paint(colorSurface1, strings.Repeat("─", rule))
}

func kindIcon(row Row) segment {
	switch {
	case row.Session:
		return segment{color: row.Color, text: iconTerminal}
	case row.Git:
		return segment{color: colorOverlay1, text: iconGit}
	}
	return segment{color: colorOverlay1, text: iconFolder}
}

func rowBadges(row Row) []segment {
	var badges []segment
	add := func(color, text string) {
		badges = append(badges, segment{text: " "}, segment{color: color, text: text})
	}
	if row.Favorite {
		add(colorYellow, iconStar)
	}
	if row.Current {
		add(colorLavender, "here")
	} else if row.Attached {
		add(colorBlue, iconAttached)
	}
	if row.Status == statusOffline {
		add(colorRed, "cached")
	}
	return badges
}

func agentSegments(agents []string) []segment {
	var segments []segment
	for _, agent := range agents {
		segments = append(segments, segment{color: agentColor(agent), text: iconAgent + " " + sanitize(agent)}, segment{text: " "})
	}
	return segments
}

// rowLines draws a row's two lines: kind, name, badges, agents, and age;
// then machine, path, and branch.
func (m *pickerModel) rowLines(row Row, selected bool, terms []queryTerm, width int) (string, string) {
	bar := segment{text: " "}
	background := lipgloss.NewStyle()
	if selected {
		bar = segment{color: colorLavender, text: "▌"}
		background = background.Background(lipgloss.Color(colorSurface0))
	}
	lead := []segment{bar, {text: " "}, kindIcon(row), {text: " "}}
	badges := rowBadges(row)
	age := segment{color: colorOverlay1, text: fmt.Sprintf("%4s", relativeAge(row.Recency, m.now()))}
	if !row.Session {
		age.text = ""
	}
	agents := agentSegments(uniqueAgents(row.Panes))
	room := func() int {
		return width - segmentsWidth(lead) - segmentsWidth(badges) - segmentsWidth(agents) - ansi.StringWidth(age.text) - 1
	}
	if room() < minNameWidth {
		agents = nil
	}
	nameColor, nameBold := colorSubtext, false
	if row.Session {
		nameColor, nameBold = "", true
	}
	name := sanitize(row.Name)
	if available := max(1, room()); ansi.StringWidth(name) > available {
		name = ansi.Truncate(name, available, "…")
	}
	left := append(append(lead, highlightMatches(name, terms, nameColor, nameBold)...), badges...)
	right := append(agents, age)
	gap := max(1, width-segmentsWidth(left)-segmentsWidth(right))
	top := append(append(left, segment{text: strings.Repeat(" ", gap)}), right...)

	separator := segment{color: colorSurface2, text: " · "}
	meta := []segment{{color: row.Color, text: sanitize(row.Host)}}
	path := abbreviatePath(sanitize(row.Path))
	var branch []segment
	if row.Branch != "" {
		branch = []segment{separator, {color: colorMauve, text: iconBranch + " " + sanitize(row.Branch)}}
	}
	if path != "" {
		pathRoom := width - 4 - segmentsWidth(meta) - ansi.StringWidth(separator.text) - segmentsWidth(branch)
		if pathRoom < minNameWidth {
			branch = nil
			pathRoom = width - 4 - segmentsWidth(meta) - ansi.StringWidth(separator.text)
		}
		if excess := ansi.StringWidth(path) - pathRoom; excess > 0 {
			path = ansi.TruncateLeft(path, excess+1, "…")
		}
		meta = append(meta, separator, segment{color: colorOverlay0, text: path})
	}
	bottom := append([]segment{bar, {text: "   "}}, append(meta, branch...)...)
	return renderSegments(top, width, background), renderSegments(bottom, width, background)
}

// highlightMatches splits text into segments, marking where query terms
// match.
func highlightMatches(text string, terms []queryTerm, color string, bold bool) []segment {
	runes := []rune(text)
	marked := make([]bool, len(runes))
	lower := []rune(strings.ToLower(text))
	if len(lower) != len(runes) {
		lower = runes
	}
	for _, term := range terms {
		if term.negate || term.text == "" {
			continue
		}
		haystack := lower
		if term.caseSensitive {
			haystack = runes
		}
		needle := []rune(term.text)
		for start := 0; start+len(needle) <= len(haystack); start++ {
			if string(haystack[start:start+len(needle)]) == term.text {
				for i := start; i < start+len(needle); i++ {
					marked[i] = true
				}
				break
			}
		}
	}
	var segments []segment
	for i := 0; i < len(runes); {
		j := i
		for j < len(runes) && marked[j] == marked[i] {
			j++
		}
		part := segment{color: color, text: string(runes[i:j]), bold: bold}
		if marked[i] {
			part = segment{color: colorPeach, text: part.text, bold: true}
		}
		segments = append(segments, part)
		i = j
	}
	return segments
}

// previewColumn renders the selected row's preview, with its hint on the
// last line.
func (m *pickerModel) previewColumn(width int) []string {
	border := paint(colorSurface1, "│") + " "
	inner := width - 2
	height := m.listHeight()
	var lines []string
	hint := ""
	if row, ok := m.current(); ok {
		ctx := previewContext{now: m.now(), width: inner, loading: m.summaryLoading[row.ID]}
		if state, ok := m.hostState(row.Host); ok {
			ctx.pending, ctx.updated = state.pending, state.updated
		}
		lines, hint = previewLines(row, ctx)
	}
	room := height
	if hint != "" && height > 1 {
		room = height - 1
		if len(lines) > room {
			lines = lines[:room]
		}
		lines = append(lines, make([]string, room-len(lines))...)
		lines = append(lines, hint)
	}
	column := make([]string, height)
	for i := range column {
		line := ""
		if i < len(lines) {
			line = lines[i]
		}
		column[i] = border + padTo(line, inner)
	}
	return column
}

func fit(value string, width int) string {
	value = sanitize(value)
	if ansi.StringWidth(value) > width {
		return ansi.Truncate(value, width, "…")
	}
	return value + strings.Repeat(" ", width-ansi.StringWidth(value))
}

func truncate(line string, width int) string {
	if ansi.StringWidth(line) > width {
		return ansi.Truncate(line, width, "…")
	}
	return line
}

func padTo(line string, width int) string {
	line = truncate(line, width)
	if gap := width - ansi.StringWidth(line); gap > 0 {
		return line + strings.Repeat(" ", gap)
	}
	return line
}
