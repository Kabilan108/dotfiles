package main

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"
)

func writeFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestBranchFromHead(t *testing.T) {
	root := t.TempDir()
	writeFile(t, filepath.Join(root, "repo/.git/HEAD"), "ref: refs/heads/feat/emr-sync\n")
	writeFile(t, filepath.Join(root, "repo/src/deep/file"), "")
	writeFile(t, filepath.Join(root, "detached/.git/HEAD"), "a41c9e2b7d0c3f1e8a9b6c5d4e3f2a1b0c9d8e7f\n")
	writeFile(t, filepath.Join(root, "repo/.git/worktrees/wt/HEAD"), "ref: refs/heads/wt-branch\n")
	writeFile(t, filepath.Join(root, "repo/.git/worktrees/wt/commondir"), "../..\n")
	writeFile(t, filepath.Join(root, "wt/.git"), "gitdir: ../repo/.git/worktrees/wt\n")
	writeFile(t, filepath.Join(root, "abs/.git"), "gitdir: "+filepath.Join(root, "repo/.git/worktrees/wt")+"\n")
	writeFile(t, filepath.Join(root, "broken/.git"), "not a gitdir line\n")
	if err := os.MkdirAll(filepath.Join(root, "plain"), 0o755); err != nil {
		t.Fatal(err)
	}
	cases := []struct {
		path    string
		session string
		dir     string
	}{
		{"repo", "feat/emr-sync", "feat/emr-sync"},
		{"repo/src/deep", "feat/emr-sync", ""},
		{"detached", "a41c9e2", "a41c9e2"},
		{"wt", "wt-branch", "wt-branch"},
		{"abs", "wt-branch", "wt-branch"},
		{"plain", "", ""},
		{"missing/dir", "", ""},
	}
	for _, c := range cases {
		path := filepath.Join(root, c.path)
		if got := sessionBranch(path); got != c.session {
			t.Errorf("sessionBranch(%s) = %q, want %q", c.path, got, c.session)
		}
		if got := gitBranch(path); got != c.dir {
			t.Errorf("gitBranch(%s) = %q, want %q", c.path, got, c.dir)
		}
	}
	repo, ok := openRepo(filepath.Join(root, "wt"))
	if !ok || repo.common != filepath.Join(root, "repo/.git") {
		t.Fatalf("worktree common dir: %+v", repo)
	}
}

func TestParsePorcelainV2(t *testing.T) {
	cases := []struct {
		name string
		out  string
		want porcelainStatus
	}{
		{"empty", "", porcelainStatus{}},
		{
			"clean with upstream",
			"# branch.oid 1234\n# branch.head main\n# branch.upstream origin/main\n# branch.ab +0 -0\n",
			porcelainStatus{upstream: "origin/main"},
		},
		{
			"ahead, behind, and changes",
			"# branch.oid 1234\n# branch.head main\n# branch.upstream origin/main\n# branch.ab +3 -2\n" +
				"1 .M N... 100644 100644 100644 abc abc src/main.go\n" +
				"2 R. N... 100644 100644 100644 abc abc R100 new.go\told.go\n" +
				"u UU N... 100644 100644 100644 100644 a b c conflict.go\n" +
				"? untracked.txt\n! ignored.log\n",
			porcelainStatus{upstream: "origin/main", ahead: 3, behind: 2, dirty: 4},
		},
		{"no upstream", "# branch.oid (initial)\n# branch.head main\n? a\n? b\n", porcelainStatus{dirty: 2}},
		{"detached", "# branch.oid 1234\n# branch.head (detached)\n1 M. N... 1 1 1 a a f\n", porcelainStatus{dirty: 1}},
	}
	for _, c := range cases {
		if got := parsePorcelainV2(c.out); got != c.want {
			t.Errorf("%s: got %+v, want %+v", c.name, got, c.want)
		}
	}
	var details GitDetails
	parseLastCommit("a41c9e2\x1f1700000000\x1fcapture panes \x1f with colors\n", &details)
	if details.Commit != "a41c9e2" || details.Time != 1700000000 || details.Subject != "capture panes \x1f with colors" {
		t.Fatalf("last commit: %+v", details)
	}
}

func TestGitCache(t *testing.T) {
	root := t.TempDir()
	dir := filepath.Join(root, "repo")
	git := filepath.Join(dir, ".git")
	writeFile(t, filepath.Join(git, "HEAD"), "ref: refs/heads/main\n")
	writeFile(t, filepath.Join(git, "index"), "index")
	writeFile(t, filepath.Join(git, "refs/heads/main"), "1111\n")
	writeFile(t, filepath.Join(git, "packed-refs"), "2222 refs/remotes/origin/main\n")
	cachePath := filepath.Join(root, "cache", "git.json")

	runs := 0
	fake := func(_ context.Context, _ string) (*GitDetails, string) {
		runs++
		return &GitDetails{Dirty: runs}, "origin/main"
	}
	cache := loadGitCache(cachePath)
	cache.run = fake
	bump := func(path string) func() {
		return func() {
			info, err := os.Stat(path)
			if err != nil {
				t.Fatal(err)
			}
			later := info.ModTime().Add(time.Second)
			if err := os.Chtimes(path, later, later); err != nil {
				t.Fatal(err)
			}
		}
	}
	steps := []struct {
		name   string
		change func()
		reload bool
		runs   int
	}{
		{name: "first read runs git", runs: 1},
		{name: "unchanged repository is a hit", runs: 1},
		{name: "a reloaded cache is a hit", reload: true, runs: 1},
		{name: "staging changes the index", change: bump(filepath.Join(git, "index")), runs: 2},
		{name: "a commit moves the branch ref", change: func() { writeFile(t, filepath.Join(git, "refs/heads/main"), "333333\n") }, runs: 3},
		{name: "a fetch rewrites packed upstream refs", change: bump(filepath.Join(git, "packed-refs")), runs: 4},
		{name: "a loose upstream ref replaces the packed one", change: func() { writeFile(t, filepath.Join(git, "refs/remotes/origin/main"), "4444\n") }, runs: 5},
		{name: "checkout changes HEAD", change: func() { writeFile(t, filepath.Join(git, "HEAD"), "ref: refs/heads/other\n") }, runs: 6},
		{name: "still a hit after all that", reload: true, runs: 6},
	}
	for _, step := range steps {
		if step.change != nil {
			step.change()
		}
		if step.reload {
			if err := cache.save(nil); err != nil {
				t.Fatal(err)
			}
			cache = loadGitCache(cachePath)
			cache.run = fake
		}
		repo, _ := openRepo(dir)
		details := cache.details(context.Background(), dir, repo)
		if runs != step.runs || details == nil || details.Dirty != runs {
			t.Fatalf("%s: %d runs (want %d), details %+v", step.name, runs, step.runs, details)
		}
	}
	info, err := os.Stat(cachePath)
	if err != nil || info.Mode().Perm() != 0o600 {
		t.Fatalf("cache file should be private: %v %v", info.Mode(), err)
	}

	failing := loadGitCache(cachePath)
	failing.run = func(context.Context, string) (*GitDetails, string) { return nil, "" }
	writeFile(t, filepath.Join(root, "other/.git/HEAD"), "ref: refs/heads/main\n")
	other, _ := openRepo(filepath.Join(root, "other"))
	if details := failing.details(context.Background(), filepath.Join(root, "other"), other); details != nil || len(failing.changed) != 0 {
		t.Fatalf("a failed git run must not be cached: %+v", details)
	}
	if err := failing.save(map[string]bool{dir: true}); err != nil {
		t.Fatal(err)
	}
	if entries := readGitCacheEntries(cachePath); len(entries) != 1 {
		t.Fatalf("save with keep should prune to kept paths: %v", entries)
	}
}

func TestReadmeLine(t *testing.T) {
	cases := []struct {
		name string
		text string
		want string
	}{
		{"empty", "", ""},
		{"plain first line", "Pipe tmux panes into an LLM and back.\nMore.", "Pipe tmux panes into an LLM and back."},
		{"heading", "\n\n## Fleet tools\n", "Fleet tools"},
		{"heading that repeats the name", "# llm-tmux\n\nPipe tmux panes.\n", "Pipe tmux panes."},
		{"badges and images", "[![CI](x)](y)\n![logo](logo.png)\n[!NOTE]\nReal text\n", "Real text"},
		{"html", "<p align=\"center\">\n<img src=x>\n</p>\nAfter html\n", "After html"},
		{"html comment", "<!-- a\nmultiline comment -->\n<!-- one line -->\nVisible\n", "Visible"},
		{"setext title", "llm-tmux\n========\nDescription\n", "Description"},
		{"rules and fences", "---\n```sh\nmake\n", "make"},
		{"crlf", "\r\n# Title\r\n", "Title"},
		{"only noise", "# llm-tmux\n\n![x](y)\n", ""},
		{"title spelled differently", "# LLM Tmux\nPipe panes.\n", "Pipe panes."},
		{"inline markdown", "**⚡ Quick:** a plugin for [Claude Code](https://x) and `tmux`\n", "⚡ Quick: a plugin for Claude Code and tmux"},
		{"bare url", "https://github.com/user-attachments/assets/7a92\nA coding agent.\n", "A coding agent."},
		{"inline html", "English | <a href=\"zh.md\">简体中文</a>\n", "English | 简体中文"},
	}
	for _, c := range cases {
		if got := readmeLine(c.text, "llm-tmux"); got != c.want {
			t.Errorf("%s: got %q, want %q", c.name, got, c.want)
		}
	}
}

func TestRunGitAgainstRealRepository(t *testing.T) {
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git is not installed")
	}
	t.Setenv("HOME", t.TempDir())
	t.Setenv("GIT_CONFIG_NOSYSTEM", "1")
	dir := t.TempDir()
	gitIn := func(args ...string) {
		t.Helper()
		command := append([]string{"git", "-C", dir, "-c", "user.name=t", "-c", "user.email=t@example.com"}, args...)
		if out, err := run(runOptions{}, command...); err != nil {
			t.Fatalf("%v: %v %s", command, err, out)
		}
	}
	gitIn("init", "-q", "-b", "main")
	writeFile(t, filepath.Join(dir, "tracked"), "one\n")
	gitIn("add", "tracked")
	gitIn("commit", "-q", "-m", "first commit")
	writeFile(t, filepath.Join(dir, "tracked"), "two\n")
	writeFile(t, filepath.Join(dir, "untracked"), "")

	repo, ok := openRepo(dir)
	if !ok {
		t.Fatal("no repository")
	}
	before := repo.fingerprint("")
	details, upstream := runGit(context.Background(), dir)
	if details == nil || details.Dirty != 2 || details.Subject != "first commit" || details.Commit == "" || details.Time == 0 || upstream != "" {
		t.Fatalf("details %+v, upstream %q", details, upstream)
	}
	if after := repo.fingerprint(""); after != before {
		t.Fatalf("git status rewrote the index, so the cache would always miss: %s then %s", before, after)
	}
}
