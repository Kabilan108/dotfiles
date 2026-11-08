package main

import (
	"strings"
	"testing"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/x/ansi"
)

func testModel(rows []Row, hosts ...FleetHost) *pickerModel {
	rank := newHostRank("jacurutu", hosts)
	rank.sortRows(rows)
	model := newPickerModel(rows, "jacurutu", hosts, map[string]hostCache{}, map[string]bool{})
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
	if len(model.visible) != 2 || !strings.Contains(model.columnHeader(), "SESSIONS") {
		t.Fatalf("sessions filter: %d rows, header %q", len(model.visible), model.columnHeader())
	}
	press(model, "ctrl+s")
	if len(model.visible) != 2 || !strings.Contains(model.columnHeader(), "DIRS") {
		t.Fatalf("dirs filter: %d rows", len(model.visible))
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
	model := testModel([]Row{long, directory("jacurutu", "/j/"+strings.Repeat("x", 200))})
	for i, line := range strings.Split(model.View(), "\n") {
		if width := ansi.StringWidth(line); width != 120 {
			t.Fatalf("line %d is %d columns wide: %q", i, width, line)
		}
	}
}
