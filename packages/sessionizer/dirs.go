package main

import (
	"context"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"
)

type DirEntry struct {
	Name string `json:"name"`
	Dir  bool   `json:"dir"`
}

type DirSummary struct {
	Branch  string      `json:"branch,omitempty"`
	Visible int         `json:"visible"`
	Hidden  int         `json:"hidden"`
	Entries []DirEntry  `json:"entries"`
	Readme  string      `json:"readme,omitempty"`
	Git     *GitDetails `json:"git,omitempty"`
}

const (
	previewEntryLimit = 40
	readmeReadLimit   = 8 << 10
	readmeLineLimit   = 200
	// gitBudget caps the git phase of one inventory, so a cold cache on a
	// host with many repositories still answers well inside the picker's
	// ssh timeout. Repositories it skips are read on a later run.
	gitBudget = 5 * time.Second
)

type foundDirectory struct {
	Name string
	Path string
}

// scanDirectories lists project directories under the search paths, in a
// stable order: search paths in config order, then by path. Like
// `fd -L -t d -d N`, it follows symlinks and skips hidden and ignored names.
func scanDirectories(config Config, overrides []string, used map[string]bool) []foundDirectory {
	roots := overrides
	if len(roots) == 0 {
		roots = config.SearchPaths
	}
	seen := map[string]bool{}
	var result []foundDirectory
	add := func(path string) {
		resolved, err := filepath.EvalSymlinks(path)
		if err != nil {
			return
		}
		if seen[resolved] || used[resolved] {
			return
		}
		seen[resolved] = true
		name := filepath.Base(resolved)
		if name == "/" || name == "." {
			name = resolved
		}
		result = append(result, foundDirectory{Name: name, Path: resolved})
	}
	for _, value := range roots {
		root, depth := parseSearchPath(value, config.MaxDepth)
		root, err := filepath.Abs(root)
		if err != nil {
			continue
		}
		if info, err := os.Stat(root); err != nil || !info.IsDir() {
			continue
		}
		if depth == 0 {
			add(root)
			continue
		}
		var found []string
		walkDirectories(root, "", 1, depth, config.Ignore, &found)
		sort.Strings(found)
		for _, path := range found {
			add(path)
		}
	}
	return result
}

func walkDirectories(dir, relative string, depth, maxDepth int, ignore []string, found *[]string) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}
	for _, entry := range entries {
		name := entry.Name()
		if strings.HasPrefix(name, ".") {
			continue
		}
		rel := name
		if relative != "" {
			rel = relative + "/" + name
		}
		if ignored(name, rel, ignore) {
			continue
		}
		path := filepath.Join(dir, name)
		info, err := os.Stat(path)
		if err != nil || !info.IsDir() {
			continue
		}
		*found = append(*found, path)
		if depth < maxDepth {
			walkDirectories(path, rel, depth+1, maxDepth, ignore, found)
		}
	}
}

func ignored(name, relative string, patterns []string) bool {
	for _, pattern := range patterns {
		pattern = strings.TrimSuffix(pattern, "/")
		target := name
		if strings.Contains(pattern, "/") {
			target = strings.TrimPrefix(relative, "/")
			pattern = strings.TrimPrefix(pattern, "/")
		}
		if matched, _ := filepath.Match(pattern, target); matched {
			return true
		}
	}
	return false
}

// summarizeDirectory lists path for the preview. It reads no git state but
// the branch; addGitDetails fills in the rest.
func summarizeDirectory(path string) *DirSummary {
	entries, err := os.ReadDir(path)
	if err != nil {
		return nil
	}
	summary := &DirSummary{Branch: gitBranch(path)}
	var visible []DirEntry
	readme := ""
	for _, entry := range entries {
		name := entry.Name()
		if strings.HasPrefix(name, ".") {
			summary.Hidden++
			continue
		}
		isDir := entry.IsDir()
		if entry.Type()&os.ModeSymlink != 0 {
			if info, err := os.Stat(filepath.Join(path, name)); err == nil {
				isDir = info.IsDir()
			}
		}
		if !isDir && readme == "" && strings.HasPrefix(strings.ToLower(name), "readme") {
			readme = name
		}
		visible = append(visible, DirEntry{Name: name, Dir: isDir})
	}
	sort.SliceStable(visible, func(i, j int) bool {
		if visible[i].Dir != visible[j].Dir {
			return visible[i].Dir
		}
		return strings.ToLower(visible[i].Name) < strings.ToLower(visible[j].Name)
	})
	summary.Visible = len(visible)
	if len(visible) > previewEntryLimit {
		visible = visible[:previewEntryLimit]
	}
	summary.Entries = visible
	if readme != "" {
		summary.Readme = readmeLine(readHead(filepath.Join(path, readme), readmeReadLimit), filepath.Base(path))
	}
	return summary
}

func readHead(path string, limit int) string {
	file, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer file.Close()
	data, _ := io.ReadAll(io.LimitReader(file, int64(limit)))
	return string(data)
}

// readmeLine picks the first line of a README that says something: not
// blank, not a badge, image, HTML, or rule, and not a heading that only
// repeats the directory's name.
func readmeLine(text, name string) string {
	inComment := false
	for _, raw := range strings.Split(text, "\n") {
		line := strings.TrimSpace(raw)
		if inComment {
			inComment = !strings.Contains(line, "-->")
			continue
		}
		if strings.HasPrefix(line, "<!--") {
			inComment = !strings.Contains(line, "-->")
			continue
		}
		if line == "" || strings.HasPrefix(line, "<") || strings.HasPrefix(line, "![") ||
			strings.HasPrefix(line, "[!") || strings.HasPrefix(line, "```") ||
			strings.Trim(line, "-=*_~ ") == "" {
			continue
		}
		line = strings.TrimSpace(strings.TrimLeft(line, "#"))
		if line == "" || strings.EqualFold(line, name) {
			continue
		}
		line = sanitize(line)
		if len([]rune(line)) > readmeLineLimit {
			line = string([]rune(line)[:readmeLineLimit])
		}
		return line
	}
	return ""
}

// addGitDetails fills in summary.Git for a repository, from cache when the
// repository hasn't changed.
func addGitDetails(ctx context.Context, summary *DirSummary, path string, cache *gitCache) {
	if summary == nil || cache == nil {
		return
	}
	repo, ok := openRepo(path)
	if !ok {
		return
	}
	summary.Git = cache.details(ctx, path, repo)
}

// summarizeDirectories summarizes every directory with bounded parallelism,
// keeping paths' order.
func summarizeDirectories(paths []string, cache *gitCache) []*DirSummary {
	ctx, cancel := context.WithTimeout(context.Background(), gitBudget)
	defer cancel()
	summaries := make([]*DirSummary, len(paths))
	jobs := make(chan int)
	var wg sync.WaitGroup
	for range min(gitWorkers, len(paths)) {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for i := range jobs {
				summaries[i] = summarizeDirectory(paths[i])
				addGitDetails(ctx, summaries[i], paths[i], cache)
			}
		}()
	}
	for i := range paths {
		jobs <- i
	}
	close(jobs)
	wg.Wait()
	return summaries
}
