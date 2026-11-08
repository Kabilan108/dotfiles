package main

import (
	"fmt"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/x/ansi"
)

const (
	machineColumnWidth = 9
	maxNameWidth       = 34
	minNameWidth       = 12
	// pointer, star, glyph, and their gaps; then " │ " and a detail like
	// "2 win · attached  5h".
	rowPrefixWidth  = 6
	minDetailWidth  = 22
	chromeLines     = 4
	minPreviewWidth = 70
)

type kindFilter int

const (
	kindAll kindFilter = iota
	kindSessions
	kindDirectories
)

type hostState struct {
	host    FleetHost
	status  string
	pending bool
}

type refreshMsg struct {
	host  FleetHost
	cache hostCache
}

type pickerModel struct {
	rows      []Row
	visible   []int
	cursor    int
	offset    int
	query     []rune
	normal    bool
	machines  []string
	machine   int
	kind      kindFilter
	width     int
	height    int
	nameWidth int
	hosts     []hostState
	rank      hostRank
	favorites map[string]bool
	selected  *Row
	message   string
	now       func() time.Time
	refresh   func(FleetHost) hostCache
}

func newPickerModel(rows []Row, localHost string, hosts []FleetHost, caches map[string]hostCache, favorites map[string]bool) *pickerModel {
	model := &pickerModel{
		rows:      rows,
		machines:  []string{"", localHost},
		rank:      newHostRank(localHost, hosts),
		favorites: favorites,
		nameWidth: maxNameWidth,
		now:       time.Now,
		refresh:   refreshHost,
	}
	for _, host := range hosts {
		model.machines = append(model.machines, host.Name)
		model.hosts = append(model.hosts, hostState{host: host, status: caches[host.Name].Status, pending: true})
	}
	model.refilter("")
	if len(model.visible) > 1 && model.rows[model.visible[0]].Current {
		model.cursor = 1
	}
	return model
}

func (m *pickerModel) Init() tea.Cmd {
	var commands []tea.Cmd
	for _, state := range m.hosts {
		host := state.host
		commands = append(commands, func() tea.Msg {
			return refreshMsg{host: host, cache: m.refresh(host)}
		})
	}
	return tea.Batch(commands...)
}

func (m *pickerModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		listWidth, _ := m.columns()
		m.nameWidth = max(minNameWidth, min(maxNameWidth, listWidth-rowPrefixWidth-machineColumnWidth-1-3-minDetailWidth))
		m.scrollToCursor()
	case refreshMsg:
		m.applyRefresh(msg)
	case tea.KeyMsg:
		return m, m.handleKey(msg)
	}
	return m, nil
}

func (m *pickerModel) applyRefresh(msg refreshMsg) {
	for i := range m.hosts {
		if m.hosts[i].host.Name == msg.host.Name {
			m.hosts[i].pending = false
			m.hosts[i].status = msg.cache.Status
		}
	}
	keep := m.selectedID()
	fresh := remoteRows(msg.host, msg.cache, m.favorites)
	m.rows = m.rank.mergeHostRows(m.rows, msg.host.Name, fresh)
	m.refilter(keep)
}

func (m *pickerModel) handleKey(key tea.KeyMsg) tea.Cmd {
	m.message = ""
	switch key.String() {
	case "ctrl+c":
		return tea.Quit
	case "enter":
		if row, ok := m.current(); ok {
			m.selected = &row
			return tea.Quit
		}
		return nil
	case "up", "ctrl+p", "ctrl+k":
		m.move(-1)
		return nil
	case "down", "ctrl+n", "ctrl+j":
		m.move(1)
		return nil
	case "pgup":
		m.page(-m.listHeight())
		return nil
	case "pgdown":
		m.page(m.listHeight())
		return nil
	case "tab":
		m.cycleMachine(1)
		return nil
	case "shift+tab":
		m.cycleMachine(-1)
		return nil
	case "ctrl+s":
		m.cycleKind()
		return nil
	case "ctrl+f":
		m.toggleFavorite()
		return nil
	}
	if m.normal {
		return m.handleNormalKey(key)
	}
	return m.handleInsertKey(key)
}

func (m *pickerModel) handleNormalKey(key tea.KeyMsg) tea.Cmd {
	switch key.String() {
	case "esc", "q":
		return tea.Quit
	case "j":
		m.move(1)
	case "k":
		m.move(-1)
	case "g":
		m.jump(0)
	case "G":
		m.jump(len(m.visible) - 1)
	case "ctrl+d":
		m.page(m.listHeight() / 2)
	case "ctrl+u":
		m.page(-m.listHeight() / 2)
	case "i", "/":
		m.normal = false
	case "f":
		m.toggleFavorite()
	case "s":
		m.cycleKind()
	}
	return nil
}

func (m *pickerModel) handleInsertKey(key tea.KeyMsg) tea.Cmd {
	switch key.String() {
	case "esc":
		m.normal = true
		return nil
	case "backspace", "ctrl+h":
		if len(m.query) > 0 {
			m.setQuery(m.query[:len(m.query)-1])
		}
		return nil
	case "ctrl+u":
		m.setQuery(nil)
		return nil
	case "ctrl+w":
		text := strings.TrimRight(string(m.query), " ")
		if index := strings.LastIndex(text, " "); index >= 0 {
			text = text[:index+1]
		} else {
			text = ""
		}
		m.setQuery([]rune(text))
		return nil
	}
	if key.Type == tea.KeyRunes && !key.Alt {
		m.setQuery(append(m.query, key.Runes...))
	} else if key.Type == tea.KeySpace {
		m.setQuery(append(m.query, ' '))
	}
	return nil
}

func (m *pickerModel) setQuery(query []rune) {
	m.query = append([]rune(nil), query...)
	m.refilter("")
}

func (m *pickerModel) current() (Row, bool) {
	if m.cursor < 0 || m.cursor >= len(m.visible) {
		return Row{}, false
	}
	return m.rows[m.visible[m.cursor]], true
}

func (m *pickerModel) selectedID() string {
	if row, ok := m.current(); ok {
		return row.ID
	}
	return ""
}

// refilter recomputes the visible rows. The cursor stays on keep when it is
// still visible and goes to the first row otherwise.
func (m *pickerModel) refilter(keep string) {
	terms := parseQuery(string(m.query))
	machine := m.machines[m.machine]
	m.visible = m.visible[:0]
	cursor := 0
	for i, row := range m.rows {
		if machine != "" && row.Host != machine {
			continue
		}
		if m.kind == kindSessions && !row.Session || m.kind == kindDirectories && row.Session {
			continue
		}
		if !row.matches(terms) {
			continue
		}
		if row.ID == keep && keep != "" {
			cursor = len(m.visible)
		}
		m.visible = append(m.visible, i)
	}
	m.cursor = cursor
	m.scrollToCursor()
}

func (m *pickerModel) move(delta int) {
	count := len(m.visible)
	if count == 0 {
		return
	}
	m.cursor = ((m.cursor+delta)%count + count) % count
	m.scrollToCursor()
}

func (m *pickerModel) page(delta int) {
	if delta == 0 {
		delta = 1
	}
	m.jump(m.cursor + delta)
}

func (m *pickerModel) jump(index int) {
	m.cursor = max(0, min(index, len(m.visible)-1))
	m.scrollToCursor()
}

func (m *pickerModel) listHeight() int {
	return max(1, m.height-chromeLines)
}

func (m *pickerModel) scrollToCursor() {
	height := m.listHeight()
	if m.cursor < m.offset {
		m.offset = m.cursor
	}
	if m.cursor >= m.offset+height {
		m.offset = m.cursor - height + 1
	}
	m.offset = max(0, min(m.offset, len(m.visible)-height))
}

func (m *pickerModel) cycleMachine(direction int) {
	count := len(m.machines)
	m.machine = ((m.machine+direction)%count + count) % count
	m.refilter("")
}

func (m *pickerModel) cycleKind() {
	m.kind = (m.kind + 1) % 3
	m.refilter("")
}

func (m *pickerModel) toggleFavorite() {
	row, ok := m.current()
	if !ok {
		return
	}
	if _, err := toggleFavorite(row); err != nil {
		m.message = "could not save favorite: " + err.Error()
		return
	}
	m.favorites = loadFavorites()
	for i := range m.rows {
		m.rows[i].Favorite = m.rows[i].isFavorite(m.favorites)
	}
	m.rank.sortRows(m.rows)
	m.refilter(row.ID)
}

func (m *pickerModel) columns() (listWidth, previewWidth int) {
	if m.width < minPreviewWidth {
		return m.width, 0
	}
	previewWidth = m.width * 45 / 100
	return m.width - previewWidth, previewWidth
}

func (m *pickerModel) View() string {
	if m.width == 0 || m.height == 0 {
		return ""
	}
	listWidth, previewWidth := m.columns()
	left := m.listLines(listWidth)
	var right []string
	if previewWidth > 0 {
		right = m.previewColumn(previewWidth)
	}
	var out strings.Builder
	for i := 0; i < m.height; i++ {
		line := ""
		if i < len(left) {
			line = left[i]
		}
		out.WriteString(padTo(line, listWidth))
		if previewWidth > 0 {
			out.WriteString(right[i])
		}
		if i < m.height-1 {
			out.WriteByte('\n')
		}
	}
	return out.String()
}

func (m *pickerModel) listLines(width int) []string {
	lines := []string{m.promptLine(width), m.columnHeader(), m.hintLine(), paint(colorBorder, strings.Repeat("─", width))}
	terms := parseQuery(string(m.query))
	end := min(len(m.visible), m.offset+m.listHeight())
	for position := m.offset; position < end; position++ {
		row := m.rows[m.visible[position]]
		lines = append(lines, m.renderRow(row, position == m.cursor, terms, width))
	}
	return lines
}

func (m *pickerModel) promptLine(width int) string {
	label := "insert> "
	if m.normal {
		label = "normal> "
	}
	prompt := paint(colorPointer, label) + string(m.query)
	if !m.normal {
		prompt += lipgloss.NewStyle().Reverse(true).Render(" ")
	}
	info := fmt.Sprintf("%d/%d", len(m.visible), len(m.rows))
	var pending []string
	for _, state := range m.hosts {
		if state.pending {
			pending = append(pending, state.host.Name)
		}
	}
	if len(pending) > 0 {
		info = "⟳ " + strings.Join(pending, " ") + "  " + info
	}
	info = paint(colorMuted, info)
	gap := width - ansi.StringWidth(prompt) - ansi.StringWidth(info) - 1
	if gap < 1 {
		return truncate(prompt, width)
	}
	return prompt + strings.Repeat(" ", gap) + info
}

func (m *pickerModel) columnHeader() string {
	machine := "ALL"
	if name := m.machines[m.machine]; name != "" {
		machine = strings.ToUpper(name)
	}
	kind := [...]string{"SESSIONS + DIRS", "SESSIONS", "DIRS"}[m.kind]
	return "      " + fit(machine, machineColumnWidth) + " " + fit(kind, m.nameWidth) + " │ DETAILS"
}

func (m *pickerModel) hintLine() string {
	if m.message != "" {
		return paint(colorWarning, m.message)
	}
	hint := "tab machine · ctrl-s kind · ctrl-f favorite · esc normal mode"
	if m.normal {
		hint = "j/k move · f favorite · s kind · i insert · q quit"
	}
	line := paint(colorDirectory, hint)
	for _, state := range m.hosts {
		if !state.pending && state.status == statusOffline {
			line += "  " + paint(colorWarning, state.host.Name+" offline")
		}
	}
	return line
}

type segment struct {
	color string
	text  string
	bold  bool
}

func (m *pickerModel) renderRow(row Row, selected bool, terms []queryTerm, width int) string {
	pointer := segment{text: " "}
	if selected {
		pointer = segment{color: colorPointer, text: "▌"}
	}
	star := segment{text: " "}
	if row.Favorite {
		star = segment{color: colorFavorite, text: "★"}
	}
	glyph := segment{color: colorDirectory, text: "·"}
	nameColor := colorDirectory
	if row.Session {
		glyph = segment{color: row.Color, text: "●"}
		nameColor = ""
	}
	segments := []segment{pointer, {text: " "}, star, {text: " "}, glyph, {text: " "},
		{color: row.Color, text: fit(row.Host, machineColumnWidth)}, {text: " "}}
	segments = append(segments, highlightMatches(fit(row.Name, m.nameWidth), terms, nameColor)...)
	segments = append(segments, segment{color: colorBorder, text: " │ "})
	segments = append(segments, m.rowDetail(row)...)

	background := lipgloss.NewStyle()
	if selected {
		background = background.Background(lipgloss.Color(colorSelection))
	}
	var out strings.Builder
	used := 0
	for _, part := range segments {
		text := part.text
		remaining := width - used
		if remaining <= 0 {
			break
		}
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

func (m *pickerModel) rowDetail(row Row) []segment {
	if !row.Session {
		return []segment{{color: colorDirectory, text: abbreviatePath(sanitize(row.Path))}}
	}
	parts := []string{row.Windows + " win"}
	if row.Current {
		parts = append(parts, "here")
	} else if row.Attached {
		parts = append(parts, "attached")
	}
	if row.Status == statusOffline {
		parts = append(parts, "cached")
	}
	segments := []segment{{color: colorMuted, text: strings.Join(parts, " · ")}}
	if age := relativeAge(row.Recency, m.now()); age != "" {
		segments = append(segments, segment{color: colorDirectory, text: "  " + age})
	}
	return segments
}

// highlightMatches splits text into segments, marking where query terms
// match.
func highlightMatches(text string, terms []queryTerm, color string) []segment {
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
		part := segment{color: color, text: string(runes[i:j])}
		if marked[i] {
			part = segment{color: colorMatch, text: part.text, bold: true}
		}
		segments = append(segments, part)
		i = j
	}
	return segments
}

func (m *pickerModel) previewColumn(width int) []string {
	border := paint(colorBorder, "│") + " "
	inner := width - 2
	var lines []string
	if row, ok := m.current(); ok {
		if !row.Session && row.Local && row.Summary == nil {
			m.rows[m.visible[m.cursor]].Summary = summarizeDirectory(row.Path)
			row = m.rows[m.visible[m.cursor]]
		}
		for _, line := range previewLines(row, m.now()) {
			wrapped := ansi.Wrap(line, inner, "")
			lines = append(lines, strings.Split(wrapped, "\n")...)
		}
	}
	column := make([]string, m.height)
	for i := range column {
		line := ""
		if i < len(lines) {
			line = truncate(lines[i], inner)
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
