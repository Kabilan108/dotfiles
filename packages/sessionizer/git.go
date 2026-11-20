package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

const (
	gitTimeout   = 2 * time.Second
	gitCacheTTL  = 10 * time.Minute
	gitWorkers   = 8
	gitWaitDelay = 100 * time.Millisecond
	gitCacheVer  = 1
)

type gitRepo struct {
	dir    string
	common string
}

func openRepo(path string) (gitRepo, bool) {
	gitPath := filepath.Join(path, ".git")
	info, err := os.Stat(gitPath)
	if err != nil {
		return gitRepo{}, false
	}
	dir := gitPath
	if !info.IsDir() {
		data, err := os.ReadFile(gitPath)
		if err != nil {
			return gitRepo{}, false
		}
		target, ok := strings.CutPrefix(strings.TrimSpace(string(data)), "gitdir:")
		if !ok {
			return gitRepo{}, false
		}
		dir = strings.TrimSpace(target)
		if !filepath.IsAbs(dir) {
			dir = filepath.Join(path, dir)
		}
	}
	repo := gitRepo{dir: dir, common: dir}
	if data, err := os.ReadFile(filepath.Join(dir, "commondir")); err == nil {
		common := strings.TrimSpace(string(data))
		if !filepath.IsAbs(common) {
			common = filepath.Join(dir, common)
		}
		repo.common = filepath.Clean(common)
	}
	return repo, true
}

func findRepo(path string) (gitRepo, bool) {
	if path == "" {
		return gitRepo{}, false
	}
	path = filepath.Clean(expandUser(path))
	for {
		if repo, ok := openRepo(path); ok {
			return repo, true
		}
		parent := filepath.Dir(path)
		if parent == path {
			return gitRepo{}, false
		}
		path = parent
	}
}

func (repo gitRepo) head() string {
	data, err := os.ReadFile(filepath.Join(repo.dir, "HEAD"))
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}

func (repo gitRepo) branch() string {
	head := repo.head()
	if ref, ok := strings.CutPrefix(head, "ref:"); ok {
		ref = strings.TrimSpace(ref)
		if branch, ok := strings.CutPrefix(ref, "refs/heads/"); ok {
			return branch
		}
		return ref
	}
	if len(head) > 7 {
		return head[:7]
	}
	return head
}

func gitBranch(path string) string {
	repo, ok := openRepo(path)
	if !ok {
		return ""
	}
	return repo.branch()
}

func sessionBranch(path string) string {
	repo, ok := findRepo(path)
	if !ok {
		return ""
	}
	return repo.branch()
}

func (repo gitRepo) fingerprint(upstream string) string {
	files := []string{filepath.Join(repo.dir, "HEAD"), filepath.Join(repo.dir, "index")}
	if ref, ok := strings.CutPrefix(repo.head(), "ref:"); ok {
		files = append(files, repo.refFiles(strings.TrimSpace(ref))...)
	}
	if upstream != "" {
		files = append(files, repo.refFiles("refs/remotes/"+upstream)...)
	}
	var parts []string
	for _, file := range files {
		info, err := os.Stat(file)
		if err != nil {
			parts = append(parts, "-")
			continue
		}
		parts = append(parts, fmt.Sprintf("%d:%d", info.ModTime().UnixNano(), info.Size()))
	}
	return strings.Join(parts, "|")
}

func (repo gitRepo) refFiles(ref string) []string {
	loose := filepath.Join(repo.common, filepath.FromSlash(ref))
	if _, err := os.Stat(loose); err == nil {
		return []string{loose}
	}
	return []string{loose, filepath.Join(repo.common, "packed-refs")}
}

type GitDetails struct {
	Dirty   int    `json:"dirty"`
	Ahead   int    `json:"ahead,omitempty"`
	Behind  int    `json:"behind,omitempty"`
	Commit  string `json:"commit,omitempty"`
	Subject string `json:"subject,omitempty"`
	Time    int64  `json:"time,omitempty"`
}

type porcelainStatus struct {
	unborn   bool
	upstream string
	ahead    int
	behind   int
	dirty    int
}

func parsePorcelainV2(out string) porcelainStatus {
	var status porcelainStatus
	for _, line := range strings.Split(out, "\n") {
		switch {
		case line == "# branch.oid (initial)":
			status.unborn = true
		case strings.HasPrefix(line, "# branch.upstream "):
			status.upstream = strings.TrimPrefix(line, "# branch.upstream ")
		case strings.HasPrefix(line, "# branch.ab "):
			for _, field := range strings.Fields(strings.TrimPrefix(line, "# branch.ab ")) {
				number, err := strconv.Atoi(field[1:])
				if err != nil {
					continue
				}
				switch field[0] {
				case '+':
					status.ahead = number
				case '-':
					status.behind = number
				}
			}
		case strings.HasPrefix(line, "1 "), strings.HasPrefix(line, "2 "),
			strings.HasPrefix(line, "u "), strings.HasPrefix(line, "? "):
			status.dirty++
		}
	}
	return status
}

func parseLastCommit(out string, details *GitDetails) {
	fields := strings.SplitN(strings.TrimRight(out, "\n"), fieldSeparator, 3)
	if len(fields) != 3 {
		return
	}
	details.Commit = fields[0]
	details.Time = parseInt(fields[1])
	details.Subject = fields[2]
}

func gitCommand(ctx context.Context, dir string, args ...string) (string, error) {
	args = append([]string{"--no-optional-locks", "-c", "core.fsmonitor=false", "-C", dir}, args...)
	cmd := exec.CommandContext(ctx, "git", args...)
	cmd.Env = append(os.Environ(), "GIT_OPTIONAL_LOCKS=0", "GIT_TERMINAL_PROMPT=0")
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Cancel = func() error { return syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL) }
	cmd.WaitDelay = gitWaitDelay
	var stdout bytes.Buffer
	cmd.Stdout = &stdout
	if err := cmd.Start(); err != nil {
		return "", err
	}
	group := cmd.Process.Pid
	err := cmd.Wait()
	syscall.Kill(-group, syscall.SIGKILL)
	if ctx.Err() != nil {
		return "", ctx.Err()
	}
	if err != nil && !errors.Is(err, exec.ErrWaitDelay) {
		return "", err
	}
	return stdout.String(), nil
}

type gitResult struct {
	details  *GitDetails
	upstream string
	complete bool
}

func runGit(ctx context.Context, path string) gitResult {
	ctx, cancel := context.WithTimeout(ctx, gitTimeout)
	defer cancel()
	out, err := gitCommand(ctx, path, "status", "--porcelain=v2", "--branch")
	if err != nil {
		return gitResult{}
	}
	status := parsePorcelainV2(out)
	result := gitResult{
		details:  &GitDetails{Dirty: status.dirty, Ahead: status.ahead, Behind: status.behind},
		upstream: status.upstream,
		complete: status.unborn,
	}
	if status.unborn {
		return result
	}
	if out, err := gitCommand(ctx, path, "log", "-1", "--format=%h%x1f%ct%x1f%s"); err == nil {
		parseLastCommit(out, result.details)
		result.complete = true
	}
	return result
}

type gitCacheEntry struct {
	Fingerprint string      `json:"fingerprint"`
	Upstream    string      `json:"upstream,omitempty"`
	Read        int64       `json:"read"`
	Details     *GitDetails `json:"details"`
}

type gitCacheFile struct {
	Version int                      `json:"version"`
	Entries map[string]gitCacheEntry `json:"entries"`
}

type gitCache struct {
	path    string
	mu      sync.Mutex
	entries map[string]gitCacheEntry
	changed map[string]bool
	run     func(context.Context, string) gitResult
	now     func() time.Time
}

func gitCachePath() string {
	return filepath.Join(cacheDir(), "git.json")
}

func readGitCacheEntries(path string) map[string]gitCacheEntry {
	data, err := os.ReadFile(path)
	if err != nil {
		return map[string]gitCacheEntry{}
	}
	var file gitCacheFile
	if json.Unmarshal(data, &file) != nil || file.Version != gitCacheVer || file.Entries == nil {
		return map[string]gitCacheEntry{}
	}
	return file.Entries
}

func loadGitCache(path string) *gitCache {
	return &gitCache{path: path, entries: readGitCacheEntries(path), changed: map[string]bool{}, run: runGit, now: time.Now}
}

func (c *gitCache) cached(path string, repo gitRepo) (*GitDetails, bool) {
	entry, ok := c.matching(path, repo)
	return entry.Details, ok
}

func (c *gitCache) matching(path string, repo gitRepo) (gitCacheEntry, bool) {
	c.mu.Lock()
	entry, ok := c.entries[path]
	c.mu.Unlock()
	if !ok || entry.Fingerprint != repo.fingerprint(entry.Upstream) {
		return gitCacheEntry{}, false
	}
	return entry, true
}

func (c *gitCache) details(ctx context.Context, path string, repo gitRepo) *GitDetails {
	if entry, ok := c.matching(path, repo); ok && c.now().Sub(time.Unix(entry.Read, 0)) < gitCacheTTL {
		return entry.Details
	}
	return c.reread(ctx, path, repo)
}

func (c *gitCache) reread(ctx context.Context, path string, repo gitRepo) *GitDetails {
	c.mu.Lock()
	previous := c.entries[path].Upstream
	c.mu.Unlock()
	before := repo.fingerprint(previous)
	result := c.run(ctx, path)
	if result.details == nil {
		return nil
	}
	fingerprint := before
	if result.upstream != previous {
		fingerprint = repo.fingerprint(result.upstream)
	}
	read := int64(0)
	if result.complete {
		read = c.now().Unix()
	}
	c.mu.Lock()
	c.entries[path] = gitCacheEntry{Fingerprint: fingerprint, Upstream: result.upstream, Read: read, Details: result.details}
	c.changed[path] = true
	c.mu.Unlock()
	return result.details
}

func (c *gitCache) save(keep map[string]bool) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if err := os.MkdirAll(filepath.Dir(c.path), 0o700); err != nil {
		return err
	}
	lock, err := os.OpenFile(c.path+".lock", os.O_CREATE|os.O_WRONLY, 0o600)
	if err != nil {
		return err
	}
	defer lock.Close()
	if err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX); err != nil {
		return err
	}
	defer syscall.Flock(int(lock.Fd()), syscall.LOCK_UN)
	disk := readGitCacheEntries(c.path)
	pruned := false
	if keep != nil {
		for path := range disk {
			if !keep[path] {
				delete(disk, path)
				pruned = true
			}
		}
	}
	if len(c.changed) == 0 && !pruned {
		return nil
	}
	for path := range c.changed {
		disk[path] = c.entries[path]
	}
	c.changed = map[string]bool{}
	data, err := json.Marshal(gitCacheFile{Version: gitCacheVer, Entries: disk})
	if err != nil {
		return err
	}
	return writeFileAtomic(c.path, data, 0o600)
}
