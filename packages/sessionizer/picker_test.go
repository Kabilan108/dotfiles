package main

import (
	"context"
	"encoding/json"
	"fmt"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/x/ansi"
)

func testModel(rows []Row, hosts ...FleetHost) *pickerModel {
	rank := newHostRank("jacurutu", hosts)
	rank.sortRows(rows)
	model := newPickerModel(rows, "jacurutu", "#89b4fa", hosts, map[string]hostCache{}, map[string]bool{})
	model.now = func() time.Time { return time.Unix(1000, 0) }
	model.Update(tea.WindowSizeMsg{Width: 120, Height: 20})
	return model
}

func press(model *pickerModel, keys ...string) {
	for _, key := range keys {
		var msg tea.KeyMsg
		switch key {
		case "esc":
			msg = tea.KeyMsg{Type: tea.KeyEsc}
		case "tab":
			msg = tea.KeyMsg{Type: tea.KeyTab}
		case "ctrl+s":
			msg = tea.KeyMsg{Type: tea.KeyCtrlS}
		case "enter":
			msg = tea.KeyMsg{Type: tea.KeyEnter}
		default:
			msg = tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune(key)}
		}
		model.Update(msg)
	}
}

func cursorID(model *pickerModel) string {
	row, _ := model.current()
	return row.ID
}

func TestCursorStartsOnPreviousSession(t *testing.T) {
	current := session("jacurutu", "$1", 900)
	current.Current = true
	model := testModel([]Row{session("jacurutu", "$2", 800), current, session("jacurutu", "$3", 700)})
	if got := cursorID(model); got != "session:jacurutu:$2" {
		t.Fatalf("cursor on %s", got)
	}
	press(model, "$")
	if got := cursorID(model); got != "session:jacurutu:$1" {
		t.Fatalf("typing should move the cursor to the first match, got %s", got)
	}
}

func TestCursorStartsOnFirstRowWithoutCurrent(t *testing.T) {
	model := testModel([]Row{session("jacurutu", "$2", 800), session("jacurutu", "$3", 700)})
	if got := cursorID(model); got != "session:jacurutu:$2" {
		t.Fatalf("cursor on %s", got)
	}
}

func TestRefreshKeepsRowsAndCursorInPlace(t *testing.T) {
	sietch := FleetHost{Name: "sietch"}
	current := session("jacurutu", "$1", 900)
	current.Current = true
	model := testModel([]Row{current, session("sietch", "$5", 800), session("jacurutu", "$2", 700)}, sietch)
	before := ids(model.rows)
	cursor := cursorID(model)
	model.Update(refreshMsg{host: sietch, cache: hostCache{Status: statusOnline, Sessions: []InventorySession{
		{ID: "$5", Name: "five", Windows: "1", LastAttached: 5000},
		{ID: "$6", Name: "six", Windows: "1", LastAttached: 6000},
	}}})
	after := ids(model.rows)
	if after[0] != before[0] || after[1] != before[1] || after[2] != before[2] || after[3] != "session:sietch:$6" {
		t.Fatalf("rows moved: before %v after %v", before, after)
	}
	if cursorID(model) != cursor {
		t.Fatalf("cursor moved from %s to %s", cursor, cursorID(model))
	}
	if model.hosts[0].pending || model.hosts[0].status != statusOnline {
		t.Fatalf("host state not updated: %+v", model.hosts[0])
	}
}

func TestFiltersAndNormalMode(t *testing.T) {
	rows := []Row{session("jacurutu", "$1", 900), directory("jacurutu", "/j/a"), session("sietch", "$5", 800), directory("sietch", "/s/a")}
	model := testModel(rows, FleetHost{Name: "sietch"})
	press(model, "ctrl+s")
	if prompt := ansi.Strip(model.promptLine(120)); len(model.visible) != 2 || !strings.Contains(prompt, "sessions only") {
		t.Fatalf("sessions filter: %d rows, prompt %q", len(model.visible), prompt)
	}
	press(model, "ctrl+s")
	if prompt := ansi.Strip(model.promptLine(120)); len(model.visible) != 2 || !strings.Contains(prompt, "directories only") {
		t.Fatalf("directories filter: %d rows, prompt %q", len(model.visible), prompt)
	}
	press(model, "ctrl+s", "tab", "tab")
	if model.machines[model.machine] != "sietch" || len(model.visible) != 2 {
		t.Fatalf("machine filter: %q, %d rows", model.machines[model.machine], len(model.visible))
	}
	press(model, "esc", "j")
	if model.cursor != 1 || len(model.query) != 0 {
		t.Fatalf("normal mode j: cursor %d query %q", model.cursor, string(model.query))
	}
	press(model, "i", "j")
	if string(model.query) != "j" {
		t.Fatalf("insert mode should type: %q", string(model.query))
	}
	press(model, "esc", "esc")
	if model.selected != nil {
		t.Fatal("esc in normal mode should abort without a selection")
	}
}

func TestViewFitsWidth(t *testing.T) {
	long := session("jacurutu", "$1", 900)
	long.Name = strings.Repeat("very-long-session-name-", 5)
	long.Windows = "3"
	long.Branch = strings.Repeat("feature/", 10)
	long.Path = "/j/" + strings.Repeat("deep/", 30)
	long.HasPanes = true
	long.Panes = []Pane{{WindowIndex: "1", WindowName: strings.Repeat("w", 40), Command: "node", Agents: []string{"claude", "codex", "opencode"}, Path: long.Path}}
	dir := directory("jacurutu", "/j/"+strings.Repeat("x", 200))
	dir.Summary = &DirSummary{Branch: "main", Readme: strings.Repeat("readme ", 40), Git: &GitDetails{Dirty: 1, Commit: "abc1234", Subject: strings.Repeat("s", 300)},
		Entries: []DirEntry{{Name: strings.Repeat("e", 80)}, {Name: "src", Dir: true}}, Visible: 2}
	for _, size := range []struct{ width, height int }{{120, 20}, {69, 12}, {70, 9}, {200, 50}, {40, 4}} {
		model := testModel([]Row{long, dir})
		model.Update(tea.WindowSizeMsg{Width: size.width, Height: size.height})
		for range 2 {
			lines := strings.Split(model.View(), "\n")
			if len(lines) != size.height {
				t.Fatalf("%dx%d: %d lines", size.width, size.height, len(lines))
			}
			for i, line := range lines {
				if width := ansi.StringWidth(line); width != size.width {
					t.Fatalf("%dx%d: line %d is %d columns wide: %q", size.width, size.height, i, width, line)
				}
			}
			model.move(1)
		}
	}
}

func favorite(row Row) Row {
	row.Favorite = true
	return row
}

func TestSectionsAndCursorSkipHeaders(t *testing.T) {
	current := session("jacurutu", "$1", 900)
	current.Current = true
	rows := []Row{
		current,
		favorite(session("sietch", "$7", 850)),
		session("jacurutu", "$2", 800),
		session("sietch", "$5", 700),
		directory("jacurutu", "/j/a"),
		directory("sietch", "/s/a"),
		// A refresh appends new favorites after the other sessions; they
		// still belong under FAVORITES.
		favorite(directory("sietch", "/s/fav")),
	}
	cases := []struct {
		name     string
		keys     []string
		sections []string
		order    []string
	}{
		{
			name:     "all",
			sections: []string{"HERE 1", "FAVORITES 2", "SESSIONS 2", "DIRECTORIES 2"},
			order: []string{"session:jacurutu:$1", "session:sietch:$7", "dir:sietch:/s/fav", "session:jacurutu:$2",
				"session:sietch:$5", "dir:jacurutu:/j/a", "dir:sietch:/s/a"},
		},
		{
			name:     "sessions only",
			keys:     []string{"ctrl+s"},
			sections: []string{"HERE 1", "FAVORITES 1", "SESSIONS 2"},
			order:    []string{"session:jacurutu:$1", "session:sietch:$7", "session:jacurutu:$2", "session:sietch:$5"},
		},
		{
			name:     "query",
			keys:     []string{"s", "i", "e"},
			sections: []string{"FAVORITES 2", "SESSIONS 1", "DIRECTORIES 1"},
			order:    []string{"session:sietch:$7", "dir:sietch:/s/fav", "session:sietch:$5", "dir:sietch:/s/a"},
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			model := newPickerModel(slices.Clone(rows), "jacurutu", "", []FleetHost{{Name: "sietch"}}, map[string]hostCache{}, map[string]bool{})
			model.Update(tea.WindowSizeMsg{Width: 120, Height: 40})
			press(model, c.keys...)
			var sections []string
			for _, item := range model.items {
				if item.header() {
					sections = append(sections, fmt.Sprintf("%s %d", sectionTitles[item.section], item.count))
				}
			}
			if !slices.Equal(sections, c.sections) {
				t.Fatalf("sections %v, want %v", sections, c.sections)
			}
			model.jump(0)
			var order []string
			for range model.visible {
				if model.items[model.itemOf[model.cursor]].header() {
					t.Fatalf("cursor on a header at %d", model.cursor)
				}
				order = append(order, cursorID(model))
				model.move(1)
			}
			if !slices.Equal(order, c.order) {
				t.Fatalf("cursor visits %v, want %v", order, c.order)
			}
			if model.cursor != 0 {
				t.Fatalf("moving past the last row should wrap to the first, got %d", model.cursor)
			}
		})
	}
}

func TestScrollShowsWholeItems(t *testing.T) {
	current := session("jacurutu", "$1", 900)
	current.Current = true
	rows := []Row{current, favorite(session("jacurutu", "$9", 899))}
	for i := range 12 {
		rows = append(rows, session("jacurutu", fmt.Sprintf("$%d", 10+i), int64(800-i)))
	}
	for i := range 12 {
		rows = append(rows, directory("jacurutu", fmt.Sprintf("/j/%02d", i)))
	}
	for _, height := range []int{7, 8, 11, 16, 25} {
		model := testModel(slices.Clone(rows))
		model.Update(tea.WindowSizeMsg{Width: 120, Height: height})
		check := func(step string) {
			t.Helper()
			first, end := model.shownItems()
			target := model.itemOf[model.cursor]
			if target < first || target >= end {
				t.Fatalf("height %d, %s: cursor item %d outside shown %d..%d", height, step, target, first, end)
			}
			if model.listHeight() >= 3 && target > 0 && model.items[target-1].header() && target-1 < first {
				t.Fatalf("height %d, %s: the section's first row is shown without its header", height, step)
			}
			lines := model.listLines(60)
			if len(lines) != model.linesBetween(first, end-1) || len(lines) > model.listHeight() {
				t.Fatalf("height %d, %s: %d lines for items %d..%d in %d rows", height, step, len(lines), first, end, model.listHeight())
			}
			if strings.Count(strings.Join(lines, "\n"), "▌") != 2 {
				t.Fatalf("height %d, %s: the selected row should show both its lines:\n%s", height, step, ansi.Strip(strings.Join(lines, "\n")))
			}
		}
		for step := range len(model.visible) + 2 {
			check(fmt.Sprintf("down %d", step))
			model.move(1)
		}
		for step := range len(model.visible) + 2 {
			check(fmt.Sprintf("up %d", step))
			model.move(-1)
		}
		press(model, "esc", "G")
		check("G")
		press(model, "g")
		check("g")
	}
}

func TestOlderInventoryRenders(t *testing.T) {
	older := `{"sessions":[{"id":"$3","name":"main","windows":"2","attached":"1","activity":900,"path":"/home/k"}],
		"directories":[{"name":"repo","path":"/home/k/repo","summary":{"branch":"main","visible":1,"hidden":0,"entries":[{"name":"src","dir":true}]}},
		{"name":"bare","path":"/home/k/bare"}]}`
	var inventory Inventory
	if err := json.Unmarshal([]byte(older), &inventory); err != nil {
		t.Fatal(err)
	}
	rows := remoteRows(FleetHost{Name: "sietch"}, hostCache{Status: statusOnline, Sessions: inventory.Sessions, Directories: inventory.Directories}, nil)
	cases := []struct {
		row     Row
		want    []string
		without []string
	}{
		{rows[0], []string{"main", "WINDOWS 2", "older sessionizer", "enter opens it through the sietch proxy"}, []string{"branch"}},
		{rows[1], []string{"repo", "directory · git", "branch   main", "CONTENTS 1", "src/"}, []string{"clean", "modified", "commit", "readme"}},
		{rows[2], []string{"bare", "sent no listing"}, []string{"git"}},
	}
	for _, c := range cases {
		lines, hint := previewLines(c.row, previewContext{now: time.Unix(1000, 0), width: 50})
		text := ansi.Strip(strings.Join(append(lines, hint), "\n"))
		for _, want := range c.want {
			if !strings.Contains(text, want) {
				t.Errorf("%s preview lacks %q:\n%s", c.row.Name, want, text)
			}
		}
		for _, unwanted := range c.without {
			if strings.Contains(text, unwanted) {
				t.Errorf("%s preview has %q:\n%s", c.row.Name, unwanted, text)
			}
		}
	}
	model := testModel(rows, FleetHost{Name: "sietch"})
	for range rows {
		model.View()
		model.move(1)
	}
}

// drain runs cmd and everything it leads to, feeding each message back to
// the model.
func drain(model *pickerModel, cmd tea.Cmd) {
	pending := []tea.Cmd{cmd}
	for len(pending) > 0 {
		next := pending[0]
		pending = pending[1:]
		if next == nil {
			continue
		}
		msg := next()
		if batch, ok := msg.(tea.BatchMsg); ok {
			pending = append(pending, batch...)
			continue
		}
		_, follow := model.Update(msg)
		pending = append(pending, follow)
	}
}

func TestSelectedDirectoryRereadsGit(t *testing.T) {
	down := tea.KeyMsg{Type: tea.KeyDown}
	up := tea.KeyMsg{Type: tea.KeyUp}
	cases := []struct {
		name string
		// seed puts a matching cache entry with dirty 99 in place first.
		seed   bool
		fail   bool
		drive  func(t *testing.T, model *pickerModel)
		before int
		after  int
		runs   int
	}{
		{
			name: "cached details show at once, then the fresh read replaces them", seed: true,
			drive:  func(_ *testing.T, model *pickerModel) { _, cmd := model.Update(down); drain(model, cmd) },
			before: 99, after: 1, runs: 1,
		},
		{
			name:  "without a cache entry the fresh read fills the preview",
			drive: func(_ *testing.T, model *pickerModel) { _, cmd := model.Update(down); drain(model, cmd) },
			after: 1, runs: 1,
		},
		{
			name: "a failed read keeps the cached details", seed: true, fail: true,
			drive:  func(_ *testing.T, model *pickerModel) { _, cmd := model.Update(down); drain(model, cmd) },
			before: 99, after: 99, runs: 1,
		},
		{
			name: "moving on before the cursor settles runs no git", seed: true,
			drive: func(_ *testing.T, model *pickerModel) {
				_, tick := model.Update(down)
				model.Update(up)
				drain(model, tick)
				model.Update(down)
			},
			before: 99, after: 99, runs: 0,
		},
		{
			name: "one read in flight per directory", seed: true,
			drive: func(t *testing.T, model *pickerModel) {
				_, tick := model.Update(down)
				_, read := model.Update(tick())
				if read == nil {
					t.Fatal("the settled cursor should start a read")
				}
				model.Update(up)
				_, again := model.Update(down)
				if _, second := model.Update(again()); second != nil {
					t.Fatal("a second read started while the first runs")
				}
				drain(model, read)
			},
			before: 99, after: 1, runs: 1,
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			dir := t.TempDir()
			writeFile(t, filepath.Join(dir, ".git/HEAD"), "ref: refs/heads/main\n")
			writeFile(t, filepath.Join(dir, ".git/index"), "index")
			repo, _ := openRepo(dir)
			cachePath := filepath.Join(t.TempDir(), "git.json")
			cache := loadGitCache(cachePath)
			runs := 0
			cache.run = func(context.Context, string) (*GitDetails, string) {
				runs++
				if c.fail {
					return nil, ""
				}
				return &GitDetails{Dirty: runs}, ""
			}
			if c.seed {
				cache.entries[dir] = gitCacheEntry{Fingerprint: repo.fingerprint(""), Read: time.Now().Unix(), Details: &GitDetails{Dirty: 99}}
			}
			row := directory("jacurutu", dir)
			row.Local, row.Git = true, true
			model := newPickerModel([]Row{session("jacurutu", "$1", 900), row}, "jacurutu", "", nil, map[string]hostCache{}, map[string]bool{})
			model.git, model.gitDebounce = cache, 0
			model.Update(tea.WindowSizeMsg{Width: 120, Height: 20})
			dirty := func() int {
				summary := model.rows[1].Summary
				if summary == nil || summary.Git == nil {
					return 0
				}
				return summary.Git.Dirty
			}
			model.Update(down)
			if got := dirty(); got != c.before {
				t.Fatalf("on selection the preview shows dirty %d, want %d", got, c.before)
			}
			model.Update(up)
			c.drive(t, model)
			if got := dirty(); got != c.after || runs != c.runs {
				t.Fatalf("after: dirty %d (want %d), %d git runs (want %d)", got, c.after, runs, c.runs)
			}
			if len(model.gitPending) != 0 {
				t.Fatalf("reads still marked running: %v", model.gitPending)
			}
			if c.runs > 0 && !c.fail {
				if entry := readGitCacheEntries(cachePath)[dir]; entry.Details == nil || entry.Details.Dirty != c.after {
					t.Fatalf("the fresh read should be saved: %+v", entry)
				}
			}
		})
	}
}
