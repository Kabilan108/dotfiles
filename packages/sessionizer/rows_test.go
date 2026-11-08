package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"slices"
	"testing"
)

func ids(rows []Row) []string {
	result := make([]string, len(rows))
	for i, row := range rows {
		result[i] = row.ID
	}
	return result
}

func session(host, id string, recency int64) Row {
	return Row{ID: sessionRowID(host, id), Session: true, Host: host, Name: host + id, Target: id, Recency: recency}
}

func directory(host, path string) Row {
	return Row{ID: directoryRowID(host, path), Host: host, Name: filepath.Base(path), Target: path, Path: path}
}

func TestSortRows(t *testing.T) {
	rank := newHostRank("jacurutu", []FleetHost{{Name: "sietch"}, {Name: "tleilax"}})
	current := session("jacurutu", "$1", 100)
	current.Current = true
	favorite := directory("sietch", "/s/fav")
	favorite.Favorite = true
	rows := []Row{
		directory("sietch", "/s/a"),
		directory("jacurutu", "/j/b"),
		session("sietch", "$9", 300),
		current,
		directory("jacurutu", "/j/a"),
		session("jacurutu", "$2", 200),
		favorite,
		directory("tleilax", "/home"),
	}
	rank.sortRows(rows)
	want := []string{
		"session:jacurutu:$1",
		"dir:sietch:/s/fav",
		"session:sietch:$9",
		"session:jacurutu:$2",
		"dir:jacurutu:/j/b",
		"dir:jacurutu:/j/a",
		"dir:sietch:/s/a",
		"dir:tleilax:/home",
	}
	if got := ids(rows); !slices.Equal(got, want) {
		t.Fatalf("order:\n got %v\nwant %v", got, want)
	}
}

func TestMergeHostRowsKeepsPositions(t *testing.T) {
	rank := newHostRank("jacurutu", []FleetHost{{Name: "sietch"}})
	rows := []Row{
		session("jacurutu", "$1", 500),
		session("sietch", "$3", 400),
		session("sietch", "$4", 300),
		session("jacurutu", "$2", 200),
		directory("jacurutu", "/j/a"),
		directory("sietch", "/s/old"),
	}
	fresh := []Row{
		session("sietch", "$4", 900),
		session("sietch", "$5", 50),
		directory("sietch", "/s/new"),
	}
	fresh[0].Windows = "7"
	merged := rank.mergeHostRows(rows, "sietch", fresh)
	want := []string{
		"session:jacurutu:$1",
		"session:sietch:$4",
		"session:jacurutu:$2",
		"session:sietch:$5",
		"dir:jacurutu:/j/a",
		"dir:sietch:/s/new",
	}
	if got := ids(merged); !slices.Equal(got, want) {
		t.Fatalf("merge:\n got %v\nwant %v", got, want)
	}
	if merged[1].Windows != "7" {
		t.Fatalf("merged row kept stale data: %+v", merged[1])
	}
}

func TestQueryMatching(t *testing.T) {
	row := Row{Host: "sietch", Name: "Dotfiles"}
	cases := []struct {
		query string
		want  bool
	}{
		{"", true},
		{"dot", true},
		{"sie dot", true},
		{"dot !sietch", false},
		{"Dot", true},
		{"DOT", false},
		{"jacurutu", false},
	}
	for _, c := range cases {
		if got := row.matches(parseQuery(c.query)); got != c.want {
			t.Errorf("%q: got %v, want %v", c.query, got, c.want)
		}
	}
}

func TestFavoriteKeysCarryOver(t *testing.T) {
	row := Row{Session: true, Host: "sietch", Name: "dotfiles", Path: "/home/k/dotfiles"}
	if !row.isFavorite(map[string]bool{"path:sietch:/home/k/dotfiles": true}) {
		t.Fatal("a session should inherit its directory's favorite")
	}
	if !row.isFavorite(map[string]bool{"session:sietch:dotfiles": true}) {
		t.Fatal("session favorite key changed")
	}
}

func TestOlderInventoryParses(t *testing.T) {
	python := `{"sessions":[{"id":"$3","name":"main","windows":"2","attached":"1","activity":1700000000,"path":"/home/k"}],
		"directories":[{"name":"repo","path":"/home/k/repo"}]}`
	var inventory Inventory
	if err := json.Unmarshal([]byte(python), &inventory); err != nil {
		t.Fatal(err)
	}
	rows := remoteRows(FleetHost{Name: "sietch"}, hostCache{Status: statusOnline, Sessions: inventory.Sessions, Directories: inventory.Directories}, nil)
	if len(rows) != 2 || rows[0].Recency != 1700000000 || !rows[0].Attached || rows[0].Windows != "2" || rows[0].HasPanes {
		t.Fatalf("unexpected rows: %+v", rows)
	}
	numeric := `{"id":"$1","name":"x","windows":3,"attached":0,"activity":5,"path":""}`
	var parsed InventorySession
	if err := json.Unmarshal([]byte(numeric), &parsed); err != nil || parsed.Windows != "3" {
		t.Fatalf("numeric windows: %v %+v", err, parsed)
	}
}

func TestScanDirectories(t *testing.T) {
	root := t.TempDir()
	for _, dir := range []string{"b", "a", "a/deep", ".hidden", "node_modules", "my-cache-dir", "used"} {
		if err := os.MkdirAll(filepath.Join(root, "repos", dir), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.WriteFile(filepath.Join(root, "repos", "file"), nil, 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(filepath.Join(root, "repos", "b"), filepath.Join(root, "repos", "link-to-b")); err != nil {
		t.Fatal(err)
	}
	config := Config{
		SearchPaths: []string{filepath.Join(root, "repos"), filepath.Join(root, "repos") + ":0", filepath.Join(root, "missing")},
		MaxDepth:    1,
		Ignore:      []string{"node_modules", "*cache*"},
	}
	used := map[string]bool{filepath.Join(root, "repos", "used"): true}
	var got []string
	for _, dir := range scanDirectories(config, nil, used) {
		rel, _ := filepath.Rel(root, dir.Path)
		got = append(got, rel)
	}
	want := []string{"repos/a", "repos/b", "repos"}
	if !slices.Equal(got, want) {
		t.Fatalf("got %v, want %v", got, want)
	}
	config.MaxDepth = 2
	config.SearchPaths = config.SearchPaths[:1]
	got = nil
	for _, dir := range scanDirectories(config, nil, used) {
		rel, _ := filepath.Rel(root, dir.Path)
		got = append(got, rel)
	}
	want = []string{"repos/a", "repos/a/deep", "repos/b"}
	if !slices.Equal(got, want) {
		t.Fatalf("depth 2: got %v, want %v", got, want)
	}
}

func TestSummarizeDirectory(t *testing.T) {
	root := t.TempDir()
	for _, name := range []string{"src", ".git"} {
		os.Mkdir(filepath.Join(root, name), 0o755)
	}
	os.WriteFile(filepath.Join(root, ".git", "HEAD"), []byte("ref: refs/heads/main\n"), 0o644)
	os.WriteFile(filepath.Join(root, "README"), nil, 0o644)
	summary := summarizeDirectory(root)
	if summary.Branch != "main" || summary.Visible != 2 || summary.Hidden != 1 || !summary.Entries[0].Dir {
		t.Fatalf("unexpected summary: %+v", summary)
	}
}

func TestInventoryCommandMatchesDeployGate(t *testing.T) {
	t.Setenv("SESSIONIZER_REMOTE_PROGRAM", "")
	if got := remoteSessionizer("--inventory"); got != `"$HOME/bin/sessionizer" --inventory` {
		t.Fatalf("deploy-gate allows only the exact inventory command, got %s", got)
	}
}
