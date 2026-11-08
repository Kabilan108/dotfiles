package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"slices"
	"syscall"
	"testing"
	"time"
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
	merged := rank.mergeHostRows(rows, "sietch", fresh, "")
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

func TestMergeKeepsCurrentRowMissingFromStaleCache(t *testing.T) {
	rank := newHostRank("jacurutu", []FleetHost{{Name: "sietch"}})
	current := session("sietch", "$9", 900)
	current.Current = true
	rows := []Row{current, session("jacurutu", "$1", 500)}
	merged := rank.mergeHostRows(rows, "sietch", []Row{session("sietch", "$3", 100)}, "")
	if got := ids(merged); !slices.Equal(got, []string{"session:sietch:$9", "session:jacurutu:$1", "session:sietch:$3"}) {
		t.Fatalf("got %v", got)
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
	t.Chdir(root)
	got = nil
	for _, dir := range scanDirectories(config, []string{"repos"}, used) {
		rel, _ := filepath.Rel(root, dir.Path)
		got = append(got, rel)
	}
	if !slices.Equal(got, want) {
		t.Fatalf("relative override: got %v, want %v", got, want)
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

func TestReadmeOnlyFromRegularFiles(t *testing.T) {
	cases := []struct {
		name  string
		setup func(t *testing.T, dir string)
		want  string
	}{
		{"regular file", func(t *testing.T, dir string) { writeFile(t, filepath.Join(dir, "README.md"), "Real text\n") }, "Real text"},
		{"fifo", func(t *testing.T, dir string) { mkfifo(t, filepath.Join(dir, "README")) }, ""},
		{"symlink to a fifo", func(t *testing.T, dir string) {
			mkfifo(t, filepath.Join(dir, ".pipe"))
			symlink(t, filepath.Join(dir, ".pipe"), filepath.Join(dir, "README"))
		}, ""},
		{"symlink to a device", func(t *testing.T, dir string) { symlink(t, "/dev/zero", filepath.Join(dir, "README")) }, ""},
		{"symlink to a regular file", func(t *testing.T, dir string) {
			writeFile(t, filepath.Join(dir, ".real"), "Linked text\n")
			symlink(t, filepath.Join(dir, ".real"), filepath.Join(dir, "README"))
		}, "Linked text"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			dir := t.TempDir()
			c.setup(t, dir)
			done := make(chan *DirSummary, 1)
			go func() { done <- summarizeDirectory(dir) }()
			select {
			case summary := <-done:
				if summary == nil || summary.Readme != c.want {
					t.Fatalf("summary %+v, want readme %q", summary, c.want)
				}
			case <-time.After(time.Second):
				t.Fatal("summarizing blocked on the README")
			}
		})
	}
	if got := readRegularHead("/dev/zero", 16); got != "" {
		t.Fatalf("read a device: %q", got)
	}
}

func mkfifo(t *testing.T, path string) {
	t.Helper()
	if err := syscall.Mkfifo(path, 0o600); err != nil {
		t.Fatal(err)
	}
}

func symlink(t *testing.T, target, path string) {
	t.Helper()
	if err := os.Symlink(target, path); err != nil {
		t.Fatal(err)
	}
}

func TestMergeKeepsSelectedRowMissingFromRefresh(t *testing.T) {
	rank := newHostRank("jacurutu", []FleetHost{{Name: "sietch"}})
	rows := []Row{session("jacurutu", "$1", 500), session("sietch", "$2", 400), session("sietch", "$3", 300)}
	cases := []struct {
		name     string
		selected string
		want     []string
	}{
		{"selected row stays", "session:sietch:$2", []string{"session:jacurutu:$1", "session:sietch:$2"}},
		{"unselected rows drop", "session:jacurutu:$1", []string{"session:jacurutu:$1"}},
		{"nothing selected", "", []string{"session:jacurutu:$1"}},
	}
	for _, c := range cases {
		if got := ids(rank.mergeHostRows(slices.Clone(rows), "sietch", nil, c.selected)); !slices.Equal(got, c.want) {
			t.Errorf("%s: got %v, want %v", c.name, got, c.want)
		}
	}
}
