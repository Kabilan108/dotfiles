package main

import (
	"cmp"
	"encoding/json"
	"os"
	"slices"
	"strings"
	"unicode"
)

type Row struct {
	ID       string
	Session  bool
	Host     string
	Color    string
	Local    bool
	Name     string
	Target   string
	Path     string
	Windows  string
	Attached bool
	Recency  int64
	Favorite bool
	Current  bool
	// Status is the remote host's cache status; empty for local rows.
	Status   string
	Panes    []Pane
	HasPanes bool
	Summary  *DirSummary
}

func sessionRowID(host, id string) string { return "session:" + host + ":" + id }
func directoryRowID(host, path string) string {
	return "dir:" + host + ":" + path
}

// favoriteKey keeps the Python picker's keys, so favorites.json carries over.
func (r Row) favoriteKey() string {
	if r.Session {
		return "session:" + r.Host + ":" + r.Name
	}
	return "path:" + r.Host + ":" + r.Path
}

func (r Row) favoriteKeys() []string {
	keys := []string{r.favoriteKey()}
	if r.Session && r.Path != "" {
		keys = append(keys, "path:"+r.Host+":"+r.Path)
	}
	return keys
}

func (r Row) isFavorite(favorites map[string]bool) bool {
	for _, key := range r.favoriteKeys() {
		if favorites[key] {
			return true
		}
	}
	return false
}

func (r Row) spec() string {
	if r.Session {
		return sessionSpec(r.Target)
	}
	return directorySpec(r.Target)
}

func localRows(state localState, host, color string, dirs []foundDirectory, favorites map[string]bool) []Row {
	var rows []Row
	for _, session := range state.userSessions() {
		row := Row{
			ID:       sessionRowID(host, session.ID),
			Session:  true,
			Host:     host,
			Color:    color,
			Local:    true,
			Name:     session.Name,
			Target:   session.ID,
			Path:     session.Path(),
			Windows:  session.Windows,
			Attached: session.Attached,
			Recency:  session.Recency(),
			Panes:    state.panes[session.ID],
			HasPanes: true,
		}
		row.Favorite = row.isFavorite(favorites)
		rows = append(rows, row)
	}
	for _, dir := range dirs {
		row := Row{
			ID:     directoryRowID(host, dir.Path),
			Host:   host,
			Color:  color,
			Local:  true,
			Name:   dir.Name,
			Target: dir.Path,
			Path:   dir.Path,
		}
		row.Favorite = row.isFavorite(favorites)
		rows = append(rows, row)
	}
	return rows
}

func remoteRows(host FleetHost, cache hostCache, favorites map[string]bool) []Row {
	var rows []Row
	for _, session := range cache.Sessions {
		if !sessionIDPattern.MatchString(session.ID) {
			continue
		}
		row := Row{
			ID:       sessionRowID(host.Name, session.ID),
			Session:  true,
			Host:     host.Name,
			Color:    host.Color,
			Name:     session.Name,
			Target:   session.ID,
			Path:     session.Path,
			Windows:  string(session.Windows),
			Attached: string(session.Attached) != "" && string(session.Attached) != "0",
			Recency:  session.Recency(),
			Status:   cache.Status,
			Panes:    session.Panes,
			HasPanes: session.Panes != nil,
		}
		row.Favorite = row.isFavorite(favorites)
		rows = append(rows, row)
	}
	for _, dir := range cache.Directories {
		if dir.Path == "" {
			continue
		}
		row := Row{
			ID:      directoryRowID(host.Name, dir.Path),
			Host:    host.Name,
			Color:   host.Color,
			Name:    dir.Name,
			Target:  dir.Path,
			Path:    dir.Path,
			Status:  cache.Status,
			Summary: dir.Summary,
		}
		row.Favorite = row.isFavorite(favorites)
		rows = append(rows, row)
	}
	return rows
}

// currentRowID names the row for the session this client shows: a local
// session, or through a proxy, the remote session it last switched to.
func currentRowID(state localState, localHost string) string {
	id := tmuxDisplay("#{session_id}")
	if id == "" {
		return ""
	}
	for _, session := range state.sessions {
		if session.ID != id {
			continue
		}
		if session.ProxyHost == "" {
			return sessionRowID(localHost, id)
		}
		if session.RemoteTarget != "" {
			return sessionRowID(session.ProxyHost, session.RemoteTarget)
		}
	}
	return ""
}

// hostRank orders machines: this one first, then remote hosts in fleet order.
type hostRank map[string]int

func newHostRank(local string, hosts []FleetHost) hostRank {
	rank := hostRank{local: 0}
	for i, host := range hosts {
		rank[host.Name] = i + 1
	}
	return rank
}

// compareRows orders the current session first, then favorites, then
// sessions by when they were last visited, then directories by machine.
// Directories on one machine keep their scan order.
func (rank hostRank) compareRows(a, b Row) int {
	if a.Current != b.Current {
		return boolFirst(a.Current)
	}
	if a.Favorite != b.Favorite {
		return boolFirst(a.Favorite)
	}
	if a.Session != b.Session {
		return boolFirst(a.Session)
	}
	if a.Session && a.Recency != b.Recency {
		return cmp.Compare(b.Recency, a.Recency)
	}
	if byHost := cmp.Compare(rank[a.Host], rank[b.Host]); byHost != 0 {
		return byHost
	}
	if a.Session {
		return cmp.Compare(strings.ToLower(a.Name), strings.ToLower(b.Name))
	}
	return 0
}

func boolFirst(first bool) int {
	if first {
		return -1
	}
	return 1
}

func (rank hostRank) sortRows(rows []Row) {
	slices.SortStableFunc(rows, rank.compareRows)
}

// mergeHostRows folds a host's fresh rows into an open picker without moving
// rows that are already shown. Rows the host no longer has drop out; new
// sessions go after the last session and new directories at the end.
func (rank hostRank) mergeHostRows(rows []Row, host string, fresh []Row) []Row {
	freshByID := make(map[string]Row, len(fresh))
	for _, row := range fresh {
		freshByID[row.ID] = row
	}
	merged := make([]Row, 0, len(rows)+len(fresh))
	for _, row := range rows {
		if row.Host != host {
			merged = append(merged, row)
			continue
		}
		update, ok := freshByID[row.ID]
		if !ok {
			continue
		}
		update.Favorite = row.Favorite
		update.Current = row.Current
		if update.Summary == nil {
			update.Summary = row.Summary
		}
		merged = append(merged, update)
		delete(freshByID, row.ID)
	}
	var addedSessions, addedDirectories []Row
	for _, row := range fresh {
		if _, isNew := freshByID[row.ID]; !isNew {
			continue
		}
		if row.Session {
			addedSessions = append(addedSessions, row)
		} else {
			addedDirectories = append(addedDirectories, row)
		}
	}
	rank.sortRows(addedSessions)
	lastSession := -1
	for i, row := range merged {
		if row.Session {
			lastSession = i
		}
	}
	merged = slices.Insert(merged, lastSession+1, addedSessions...)
	return append(merged, addedDirectories...)
}

func loadFavorites() map[string]bool {
	favorites := map[string]bool{}
	data, err := os.ReadFile(favoritesPath())
	if err != nil {
		return favorites
	}
	var keys []string
	if json.Unmarshal(data, &keys) != nil {
		return favorites
	}
	for _, key := range keys {
		favorites[key] = true
	}
	return favorites
}

func saveFavorites(favorites map[string]bool) error {
	keys := make([]string, 0, len(favorites))
	for key := range favorites {
		keys = append(keys, key)
	}
	slices.Sort(keys)
	data, err := json.MarshalIndent(keys, "", "  ")
	if err != nil {
		return err
	}
	return writeFileAtomic(favoritesPath(), append(data, '\n'), 0o644)
}

// toggleFavorite flips row's favorite state on disk and reports the new one.
func toggleFavorite(row Row) (bool, error) {
	favorites := loadFavorites()
	favorite := !row.isFavorite(favorites)
	if favorite {
		favorites[row.favoriteKey()] = true
	} else {
		for _, key := range row.favoriteKeys() {
			delete(favorites, key)
		}
	}
	return favorite, saveFavorites(favorites)
}

type queryTerm struct {
	text          string
	negate        bool
	caseSensitive bool
}

// parseQuery splits a query into terms that must all match the row's machine
// and name. "!term" excludes; any uppercase letter makes a term case
// sensitive.
func parseQuery(query string) []queryTerm {
	var terms []queryTerm
	for _, field := range strings.Fields(query) {
		term := queryTerm{text: field}
		if strings.HasPrefix(field, "!") && len(field) > 1 {
			term.negate = true
			term.text = field[1:]
		}
		term.caseSensitive = strings.IndexFunc(term.text, unicode.IsUpper) >= 0
		if !term.caseSensitive {
			term.text = strings.ToLower(term.text)
		}
		terms = append(terms, term)
	}
	return terms
}

func (r Row) matches(terms []queryTerm) bool {
	haystack := r.Host + " " + r.Name
	lower := strings.ToLower(haystack)
	for _, term := range terms {
		target := lower
		if term.caseSensitive {
			target = haystack
		}
		if strings.Contains(target, term.text) == term.negate {
			return false
		}
	}
	return true
}
