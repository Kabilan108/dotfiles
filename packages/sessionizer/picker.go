package main

import (
	"context"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
)

const (
	// host chips, prompt, and a rule above the list; a rule and the key
	// hints below it.
	chromeLines     = 5
	minPreviewWidth = 70
	listPercent     = 53
	// gitDebounce waits for the cursor to settle before reading a
	// directory's git status, so scrolling past repositories runs no git.
	gitDebounce = 150 * time.Millisecond
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
	updated int64
	pending bool
}

type refreshMsg struct {
	host  FleetHost
	cache hostCache
}

type gitMsg struct {
	id      string
	details *GitDetails
}

type gitTickMsg struct {
	id string
}

// listItem is one entry of the drawn list: a section header, or the row at
// visible[row].
type listItem struct {
	section section
	count   int
	row     int
}

func (item listItem) header() bool { return item.row < 0 }

func (item listItem) height() int {
	if item.header() {
		return 1
	}
	return 2
}

type pickerModel struct {
	rows    []Row
	visible []int
	items   []listItem
	// itemOf maps a visible position to its item; lineStart[i] is the line
	// item i starts on, with the total line count at the end.
	itemOf      []int
	lineStart   []int
	hostCounts  map[string]int
	cursor      int
	top         int
	query       []rune
	normal      bool
	machines    []string
	colors      map[string]string
	machine     int
	kind        kindFilter
	width       int
	height      int
	hosts       []hostState
	rank        hostRank
	favorites   map[string]bool
	selected    *Row
	message     string
	now         func() time.Time
	refresh     func(FleetHost) hostCache
	git         *gitCache
	gitDebounce time.Duration
	// gitSelected is the selection a git read was last scheduled for;
	// gitPending holds the rows whose read is running.
	gitSelected string
	gitPending  map[string]bool
}

func newPickerModel(rows []Row, localHost, localColor string, hosts []FleetHost, caches map[string]hostCache, favorites map[string]bool) *pickerModel {
	model := &pickerModel{
		rows:        rows,
		machines:    []string{"", localHost},
		colors:      map[string]string{localHost: localColor},
		rank:        newHostRank(localHost, hosts),
		favorites:   favorites,
		now:         time.Now,
		refresh:     refreshHost,
		gitDebounce: gitDebounce,
		gitPending:  map[string]bool{},
	}
	for _, host := range hosts {
		model.machines = append(model.machines, host.Name)
		model.colors[host.Name] = host.Color
		cache := caches[host.Name]
		model.hosts = append(model.hosts, hostState{host: host, status: cache.Status, updated: cache.Updated, pending: true})
	}
	model.refilter("")
	if len(model.visible) > 1 && model.rows[model.visible[0]].Current {
		model.cursor = 1
		model.scrollToCursor()
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
	var command tea.Cmd
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.scrollToCursor()
	case refreshMsg:
		m.applyRefresh(msg)
	case gitMsg:
		m.applyGit(msg)
	case gitTickMsg:
		command = m.startGit(msg)
	case tea.KeyMsg:
		command = m.handleKey(msg)
	}
	if m.selected != nil {
		return m, command
	}
	return m, tea.Batch(command, m.loadSelected())
}

func (m *pickerModel) applyRefresh(msg refreshMsg) {
	for i := range m.hosts {
		if m.hosts[i].host.Name == msg.host.Name {
			m.hosts[i].pending = false
			m.hosts[i].status = msg.cache.Status
			m.hosts[i].updated = msg.cache.Updated
		}
	}
	keep := m.selectedID()
	fresh := remoteRows(msg.host, msg.cache, m.favorites)
	m.rows = m.rank.mergeHostRows(m.rows, msg.host.Name, fresh)
	m.refilter(keep)
}

func (m *pickerModel) applyGit(msg gitMsg) {
	delete(m.gitPending, msg.id)
	if msg.details == nil {
		return
	}
	for i := range m.rows {
		if m.rows[i].ID == msg.id && m.rows[i].Summary != nil {
			summary := *m.rows[i].Summary
			summary.Git = msg.details
			m.rows[i].Summary = &summary
		}
	}
}

// loadSelected reads the selected local directory for the preview. Cached
// git details show at once when the repository hasn't changed; either way a
// fresh read follows in the background once the cursor settles, because the
// cache can't see unstaged edits.
func (m *pickerModel) loadSelected() tea.Cmd {
	if m.cursor < 0 || m.cursor >= len(m.visible) {
		return nil
	}
	row := &m.rows[m.visible[m.cursor]]
	if row.Session || !row.Local {
		m.gitSelected = row.ID
		return nil
	}
	if row.Summary == nil {
		row.Summary = summarizeDirectory(row.Path)
		if row.Summary == nil {
			return nil
		}
		if repo, ok := openRepo(row.Path); ok && m.git != nil {
			if details, ok := m.git.cached(row.Path, repo); ok {
				row.Summary.Git = details
			}
		}
	}
	if m.git == nil || !row.Git || m.gitSelected == row.ID {
		return nil
	}
	m.gitSelected = row.ID
	id := row.ID
	return tea.Tick(m.gitDebounce, func(time.Time) tea.Msg { return gitTickMsg{id: id} })
}

// startGit reads the selected directory's git status once the cursor has
// rested on it, unless a read for it is already running.
func (m *pickerModel) startGit(msg gitTickMsg) tea.Cmd {
	row, ok := m.current()
	if !ok || row.ID != msg.id || m.gitPending[msg.id] || m.git == nil {
		return nil
	}
	m.gitPending[msg.id] = true
	path, cache := row.Path, m.git
	return func() tea.Msg {
		var details *GitDetails
		if repo, ok := openRepo(path); ok {
			details = cache.reread(context.Background(), path, repo)
		}
		cache.save(nil)
		return gitMsg{id: msg.id, details: details}
	}
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
		m.page(-m.pageRows())
		return nil
	case "pgdown":
		m.page(m.pageRows())
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
		m.page(m.pageRows() / 2)
	case "ctrl+u":
		m.page(-m.pageRows() / 2)
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

func (m *pickerModel) kindAllows(row Row) bool {
	switch m.kind {
	case kindSessions:
		return row.Session
	case kindDirectories:
		return !row.Session
	}
	return true
}

// refilter recomputes the visible rows, grouped by section in row order.
// The cursor stays on keep when it is still visible and goes to the first
// row otherwise.
func (m *pickerModel) refilter(keep string) {
	terms := parseQuery(string(m.query))
	machine := m.machines[m.machine]
	var sections [sectionCount][]int
	m.hostCounts = map[string]int{}
	for i, row := range m.rows {
		if !m.kindAllows(row) || !row.matches(terms) {
			continue
		}
		m.hostCounts[row.Host]++
		if machine != "" && row.Host != machine {
			continue
		}
		sections[row.section()] = append(sections[row.section()], i)
	}
	m.visible, m.items, m.itemOf = m.visible[:0], m.items[:0], m.itemOf[:0]
	cursor := 0
	for kind, indexes := range sections {
		if len(indexes) == 0 {
			continue
		}
		m.items = append(m.items, listItem{section: section(kind), count: len(indexes), row: -1})
		for _, index := range indexes {
			if keep != "" && m.rows[index].ID == keep {
				cursor = len(m.visible)
			}
			m.itemOf = append(m.itemOf, len(m.items))
			m.items = append(m.items, listItem{section: section(kind), row: len(m.visible)})
			m.visible = append(m.visible, index)
		}
	}
	m.lineStart = m.lineStart[:0]
	line := 0
	for _, item := range m.items {
		m.lineStart = append(m.lineStart, line)
		line += item.height()
	}
	m.lineStart = append(m.lineStart, line)
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

func (m *pickerModel) pageRows() int {
	return max(1, m.listHeight()/2)
}

// linesBetween counts the lines items first through last take.
func (m *pickerModel) linesBetween(first, last int) int {
	return m.lineStart[last+1] - m.lineStart[first]
}

// scrollToCursor moves the top of the list as little as it can to show the
// cursor's row whole, with its section header when it is the section's
// first row. The list always starts on a whole item.
func (m *pickerModel) scrollToCursor() {
	if len(m.items) == 0 || len(m.visible) == 0 {
		m.top = 0
		return
	}
	height := m.listHeight()
	target := m.itemOf[m.cursor]
	first := target
	if first > 0 && m.items[first-1].header() {
		first--
	}
	if first < m.top {
		m.top = first
	}
	for m.top < target && m.linesBetween(m.top, target) > height {
		m.top++
	}
	last := len(m.items) - 1
	for m.top > 0 && m.linesBetween(m.top-1, last) <= height {
		m.top--
	}
}

// shownItems is the range of items that fit whole from the top.
func (m *pickerModel) shownItems() (int, int) {
	height := m.listHeight()
	end := m.top
	for end < len(m.items) && m.linesBetween(m.top, end) <= height {
		end++
	}
	return m.top, end
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

func (m *pickerModel) hostState(name string) (hostState, bool) {
	for _, state := range m.hosts {
		if state.host.Name == name {
			return state, true
		}
	}
	return hostState{}, false
}

func (m *pickerModel) columns() (listWidth, previewWidth int) {
	if m.width < minPreviewWidth {
		return m.width, 0
	}
	listWidth = m.width * listPercent / 100
	return listWidth, m.width - listWidth
}
