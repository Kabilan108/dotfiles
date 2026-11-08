package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
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
		{"unborn, no upstream", "# branch.oid (initial)\n# branch.head main\n? a\n? b\n", porcelainStatus{unborn: true, dirty: 2}},
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
	fake := func(_ context.Context, _ string) gitResult {
		runs++
		return gitResult{details: &GitDetails{Dirty: runs}, upstream: "origin/main", complete: true}
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
	failing.run = func(context.Context, string) gitResult { return gitResult{} }
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
	result := runGit(context.Background(), dir)
	details := result.details
	if details == nil || details.Dirty != 2 || details.Subject != "first commit" || details.Commit == "" || details.Time == 0 || result.upstream != "" || !result.complete {
		t.Fatalf("result %+v, details %+v", result, details)
	}
	if after := repo.fingerprint(""); after != before {
		t.Fatalf("git status rewrote the index, so the cache would always miss: %s then %s", before, after)
	}
}

func TestGitCacheTTL(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, filepath.Join(dir, ".git/HEAD"), "ref: refs/heads/main\n")
	repo, _ := openRepo(dir)
	base := time.Unix(1_700_000_000, 0)
	cases := []struct {
		name  string
		read  int64
		age   time.Duration
		reran bool
	}{
		{name: "just read", read: base.Unix(), reran: false},
		{name: "just under ten minutes", read: base.Unix(), age: gitCacheTTL - time.Second, reran: false},
		{name: "ten minutes", read: base.Unix(), age: gitCacheTTL, reran: true},
		{name: "an hour", read: base.Unix(), age: time.Hour, reran: true},
		{name: "entry from before entries had a read time", read: 0, reran: true},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			runs := 0
			cache := loadGitCache(filepath.Join(t.TempDir(), "git.json"))
			cache.now = func() time.Time { return base.Add(c.age) }
			cache.run = func(context.Context, string) gitResult {
				runs++
				return gitResult{details: &GitDetails{Dirty: 7}, complete: true}
			}
			cache.entries[dir] = gitCacheEntry{Fingerprint: repo.fingerprint(""), Read: c.read, Details: &GitDetails{Dirty: 1}}
			details := cache.details(context.Background(), dir, repo)
			if reran := runs == 1; reran != c.reran {
				t.Fatalf("ran git %d times, want rerun %v", runs, c.reran)
			}
			want := 1
			if c.reran {
				want = 7
				if cache.entries[dir].Read != base.Add(c.age).Unix() {
					t.Fatalf("a rerun should restamp the entry: %+v", cache.entries[dir])
				}
			}
			if details == nil || details.Dirty != want {
				t.Fatalf("details %+v, want dirty %d", details, want)
			}
			if cached, ok := cache.cached(dir, repo); !ok || cached.Dirty != want {
				t.Fatalf("an unchanged repository's details should still show however old: %+v %v", cached, ok)
			}
		})
	}
}

// fakeGit puts a git on PATH that runs script with the subcommand in $cmd and
// logs each subcommand to the returned file.
func fakeGit(t *testing.T, script string) string {
	t.Helper()
	dir := t.TempDir()
	calls := filepath.Join(dir, "calls")
	body := "#!/bin/sh\ncmd=\nfor a; do case $a in status|log) cmd=$a; break;; esac; done\necho $cmd >> " + calls + "\n" + script
	if err := os.WriteFile(filepath.Join(dir, "git"), []byte(body), 0o700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir+":"+os.Getenv("PATH"))
	return calls
}

func gitCalls(t *testing.T, calls string) string {
	t.Helper()
	data, err := os.ReadFile(calls)
	if err != nil && !os.IsNotExist(err) {
		t.Fatal(err)
	}
	return strings.Join(strings.Fields(string(data)), " ")
}

const (
	fakeStatus = `printf '# branch.oid abc\n# branch.head main\n1 .M N... 1 1 1 a a f\n'`
	fakeLog    = `printf 'abc1234\037%s\037subject\n' 1700000000`
)

func TestRunGitResults(t *testing.T) {
	cases := []struct {
		name     string
		script   string
		deadline time.Duration
		within   time.Duration
		details  bool
		commit   string
		complete bool
		calls    string
	}{
		{
			name:   "status and log",
			script: "case $cmd in status) " + fakeStatus + ";; log) " + fakeLog + ";; esac\n",
			within: time.Second, details: true, commit: "abc1234", complete: true, calls: "status log",
		},
		{
			name:   "a failing log leaves the read incomplete",
			script: "case $cmd in status) " + fakeStatus + ";; log) exit 1;; esac\n",
			within: time.Second, details: true, calls: "status log",
		},
		{
			name:   "an unborn repository has no commit to read",
			script: "case $cmd in status) printf '# branch.oid (initial)\\n# branch.head main\\n? new\\n';; log) exit 128;; esac\n",
			within: time.Second, details: true, complete: true, calls: "status",
		},
		{
			name:   "a failing status gives nothing",
			script: "exit 128\n",
			within: time.Second, calls: "status",
		},
		{
			name:     "status and log share the caller's deadline",
			script:   "sleep 0.18\ncase $cmd in status) " + fakeStatus + ";; log) " + fakeLog + ";; esac\n",
			deadline: 250 * time.Millisecond,
			within:   400 * time.Millisecond, details: true, calls: "status log",
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			calls := fakeGit(t, c.script)
			ctx := context.Background()
			if c.deadline > 0 {
				var cancel context.CancelFunc
				ctx, cancel = context.WithTimeout(ctx, c.deadline)
				defer cancel()
			}
			start := time.Now()
			result := runGit(ctx, t.TempDir())
			if elapsed := time.Since(start); elapsed > c.within {
				t.Fatalf("took %s, want under %s", elapsed, c.within)
			}
			if (result.details != nil) != c.details || result.complete != c.complete {
				t.Fatalf("result %+v, want details %v complete %v", result, c.details, c.complete)
			}
			if c.details && result.details.Commit != c.commit {
				t.Fatalf("commit %q, want %q", result.details.Commit, c.commit)
			}
			if got := gitCalls(t, calls); got != c.calls {
				t.Fatalf("git ran %q, want %q", got, c.calls)
			}
		})
	}
}

// processGone reports whether pid has exited, counting an unreaped zombie
// as gone.
func processGone(pid int) bool {
	data, err := os.ReadFile(fmt.Sprintf("/proc/%d/stat", pid))
	if err != nil {
		return true
	}
	stat := string(data)
	return strings.HasPrefix(strings.TrimSpace(stat[strings.LastIndex(stat, ")")+1:]), "Z")
}

func TestGitHelpersDieWithGit(t *testing.T) {
	cases := []struct {
		name     string
		script   string
		deadline time.Duration
		details  bool
	}{
		{
			name:     "a helper holding the pipes is killed at the deadline",
			script:   "sleep 3 &\necho $! > $HELPER\nwait\n",
			deadline: 150 * time.Millisecond,
		},
		{
			name:     "a helper left behind by a git that exited is killed",
			script:   "sleep 3 &\necho $! > $HELPER\ncase $cmd in status) " + fakeStatus + ";; log) " + fakeLog + ";; esac\n",
			deadline: 2 * time.Second,
			details:  true,
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			helper := filepath.Join(t.TempDir(), "helper")
			t.Setenv("HELPER", helper)
			fakeGit(t, c.script)
			ctx, cancel := context.WithTimeout(context.Background(), c.deadline)
			defer cancel()
			start := time.Now()
			result := runGit(ctx, t.TempDir())
			if elapsed := time.Since(start); elapsed > c.deadline+time.Second {
				t.Fatalf("took %s with a %s deadline", elapsed, c.deadline)
			}
			if (result.details != nil) != c.details {
				t.Fatalf("result %+v, want details %v", result, c.details)
			}
			data, err := os.ReadFile(helper)
			if err != nil {
				t.Fatal(err)
			}
			pid, err := strconv.Atoi(strings.TrimSpace(strings.Split(string(data), "\n")[0]))
			if err != nil {
				t.Fatal(err)
			}
			for range 50 {
				if processGone(pid) {
					return
				}
				time.Sleep(20 * time.Millisecond)
			}
			syscall.Kill(pid, syscall.SIGKILL)
			t.Fatalf("helper %d outlived git", pid)
		})
	}
}

func TestRealGitSkipsSlowFsmonitor(t *testing.T) {
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git is not installed")
	}
	t.Setenv("HOME", t.TempDir())
	t.Setenv("GIT_CONFIG_NOSYSTEM", "1")
	dir := t.TempDir()
	for _, args := range [][]string{{"init", "-q"}, {"config", "core.fsmonitor", filepath.Join(dir, "monitor")}} {
		if out, err := run(runOptions{}, append([]string{"git", "-C", dir}, args...)...); err != nil {
			t.Fatalf("git %v: %v %s", args, err, out)
		}
	}
	writeFile(t, filepath.Join(dir, "tracked"), "x")
	if out, err := run(runOptions{}, "git", "-C", dir, "-c", "core.fsmonitor=false", "add", "tracked"); err != nil {
		t.Fatalf("git add: %v %s", err, out)
	}
	if err := os.WriteFile(filepath.Join(dir, "monitor"), []byte("#!/bin/sh\nsleep 3\n"), 0o700); err != nil {
		t.Fatal(err)
	}
	start := time.Now()
	result := runGit(context.Background(), dir)
	if elapsed := time.Since(start); elapsed > time.Second || result.details == nil {
		t.Fatalf("a configured fsmonitor ran: took %s, result %+v", elapsed, result)
	}
}

func TestGitCachePartialReads(t *testing.T) {
	cases := []struct {
		name     string
		complete bool
		reruns   bool
	}{
		{name: "a complete read is fresh for the TTL", complete: true, reruns: false},
		{name: "a read missing its commit is retried next time", complete: false, reruns: true},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			dir := t.TempDir()
			writeFile(t, filepath.Join(dir, ".git/HEAD"), "ref: refs/heads/main\n")
			repo, _ := openRepo(dir)
			runs := 0
			cache := loadGitCache(filepath.Join(t.TempDir(), "git.json"))
			cache.run = func(context.Context, string) gitResult {
				runs++
				return gitResult{details: &GitDetails{Dirty: 3}, complete: c.complete}
			}
			if details := cache.details(context.Background(), dir, repo); details == nil || details.Dirty != 3 {
				t.Fatalf("the partial status should still show: %+v", details)
			}
			if shown, ok := cache.cached(dir, repo); !ok || shown.Dirty != 3 {
				t.Fatalf("the preview should find the stored read: %+v %v", shown, ok)
			}
			cache.details(context.Background(), dir, repo)
			if reran := runs == 2; reran != c.reruns {
				t.Fatalf("git ran %d times, want rerun %v", runs, c.reruns)
			}
		})
	}
}

func TestGitCacheSavesAcrossWriters(t *testing.T) {
	path := filepath.Join(t.TempDir(), "git.json")
	const writers, entries = 4, 5000
	caches := make([]*gitCache, writers)
	for w := range caches {
		caches[w] = loadGitCache(path)
		for i := range entries {
			key := fmt.Sprintf("/%d/%d", w, i)
			caches[w].entries[key] = gitCacheEntry{Read: 1, Details: &GitDetails{Dirty: i}}
			caches[w].changed[key] = true
		}
	}
	start := make(chan struct{})
	var wg sync.WaitGroup
	for _, cache := range caches {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			if err := cache.save(nil); err != nil {
				t.Error(err)
			}
		}()
	}
	close(start)
	wg.Wait()
	if got := len(readGitCacheEntries(path)); got != writers*entries {
		t.Fatalf("kept %d of %d entries written at once", got, writers*entries)
	}
}
