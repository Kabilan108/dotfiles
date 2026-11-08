package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
)

// The inventory is what `sessionizer --inventory` prints for another host's
// picker. The Python picker read id, name, windows, attached, activity, and
// path, with windows and attached as strings; keep those as they were so
// mixed versions still read each other.
type Inventory struct {
	Sessions    []InventorySession   `json:"sessions"`
	Directories []InventoryDirectory `json:"directories"`
}

type InventorySession struct {
	ID           string     `json:"id"`
	Name         string     `json:"name"`
	Windows      flexString `json:"windows"`
	Attached     flexString `json:"attached"`
	Activity     int64      `json:"activity"`
	Path         string     `json:"path"`
	LastAttached int64      `json:"last_attached,omitempty"`
	Created      int64      `json:"created,omitempty"`
	Branch       string     `json:"branch,omitempty"`
	Panes        []Pane     `json:"panes,omitempty"`
}

type InventoryDirectory struct {
	Name    string      `json:"name"`
	Path    string      `json:"path"`
	Summary *DirSummary `json:"summary,omitempty"`
}

// Recency matches tmuxSession.Recency. An older host's inventory has only
// activity, which already folds in last_attached.
func (s InventorySession) Recency() int64 {
	if s.LastAttached > 0 {
		return s.LastAttached
	}
	if s.Created > 0 {
		return s.Created
	}
	return s.Activity
}

type flexString string

func (f *flexString) UnmarshalJSON(data []byte) error {
	var text string
	if err := json.Unmarshal(data, &text); err == nil {
		*f = flexString(text)
		return nil
	}
	var number json.Number
	if err := json.Unmarshal(data, &number); err != nil {
		return fmt.Errorf("expected string or number, got %s", data)
	}
	*f = flexString(number.String())
	return nil
}

var sessionIDPattern = regexp.MustCompile(`^\$[0-9]+$`)

type localState struct {
	sessions []tmuxSession
	panes    map[string][]Pane
}

func readLocalState() localState {
	sessions := listTmuxSessions()
	if len(sessions) == 0 {
		return localState{panes: map[string][]Pane{}}
	}
	return localState{sessions: sessions, panes: listAllPanes()}
}

// userSessions drops the picker's own proxy sessions.
func (s localState) userSessions() []tmuxSession {
	var result []tmuxSession
	for _, session := range s.sessions {
		if session.ProxyHost == "" && sessionIDPattern.MatchString(session.ID) {
			result = append(result, session)
		}
	}
	return result
}

func (s localState) usedPaths() map[string]bool {
	used := map[string]bool{}
	for _, session := range s.sessions {
		for _, path := range []string{session.RegisteredPath, session.SessionPath} {
			if path == "" {
				continue
			}
			if resolved, err := filepath.EvalSymlinks(expandUser(path)); err == nil {
				used[resolved] = true
			}
		}
	}
	return used
}

func (s localState) inventorySession(session tmuxSession) InventorySession {
	attached := "0"
	if session.Attached {
		attached = "1"
	}
	return InventorySession{
		ID:           session.ID,
		Name:         session.Name,
		Windows:      flexString(session.Windows),
		Attached:     flexString(attached),
		Activity:     max(session.Activity, session.LastAttached),
		Path:         session.Path(),
		LastAttached: session.LastAttached,
		Created:      session.Created,
		Branch:       sessionBranch(session.Path()),
		Panes:        s.panes[session.ID],
	}
}

func buildInventory(config Config) Inventory {
	state := readLocalState()
	inventory := Inventory{Sessions: []InventorySession{}, Directories: []InventoryDirectory{}}
	for _, session := range state.userSessions() {
		inventory.Sessions = append(inventory.Sessions, state.inventorySession(session))
	}
	dirs := scanDirectories(config, nil, state.usedPaths())
	paths := make([]string, len(dirs))
	keep := make(map[string]bool, len(dirs))
	for i, dir := range dirs {
		paths[i] = dir.Path
		keep[dir.Path] = true
	}
	cache := loadGitCache(gitCachePath())
	summaries := summarizeDirectories(paths, cache)
	if err := cache.save(keep); err != nil {
		fmt.Fprintln(os.Stderr, "sessionizer: could not save the git cache:", err)
	}
	for i, dir := range dirs {
		inventory.Directories = append(inventory.Directories, InventoryDirectory{
			Name:    dir.Name,
			Path:    dir.Path,
			Summary: summaries[i],
		})
	}
	return inventory
}

func printInventory(config Config) error {
	data, err := json.Marshal(buildInventory(config))
	if err != nil {
		return err
	}
	fmt.Println(string(data))
	return nil
}

func windowsCount(value flexString) int {
	number, _ := strconv.Atoi(string(value))
	return number
}
