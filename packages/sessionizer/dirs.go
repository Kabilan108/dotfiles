package main

import (
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type DirEntry struct {
	Name string `json:"name"`
	Dir  bool   `json:"dir"`
}

type DirSummary struct {
	Branch  string     `json:"branch,omitempty"`
	Visible int        `json:"visible"`
	Hidden  int        `json:"hidden"`
	Entries []DirEntry `json:"entries"`
}

const previewEntryLimit = 40

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
		root = filepath.Clean(root)
		if !filepath.IsAbs(root) {
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

func summarizeDirectory(path string) *DirSummary {
	entries, err := os.ReadDir(path)
	if err != nil {
		return nil
	}
	summary := &DirSummary{Branch: gitBranch(path)}
	var visible []DirEntry
	for _, entry := range entries {
		if strings.HasPrefix(entry.Name(), ".") {
			summary.Hidden++
			continue
		}
		isDir := entry.IsDir()
		if entry.Type()&os.ModeSymlink != 0 {
			if info, err := os.Stat(filepath.Join(path, entry.Name())); err == nil {
				isDir = info.IsDir()
			}
		}
		visible = append(visible, DirEntry{Name: entry.Name(), Dir: isDir})
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
	return summary
}

func gitBranch(path string) string {
	gitPath := filepath.Join(path, ".git")
	info, err := os.Stat(gitPath)
	if err != nil {
		return ""
	}
	headPath := filepath.Join(gitPath, "HEAD")
	if !info.IsDir() {
		data, err := os.ReadFile(gitPath)
		if err != nil {
			return ""
		}
		gitDir, ok := strings.CutPrefix(strings.TrimSpace(string(data)), "gitdir: ")
		if !ok {
			return ""
		}
		if !filepath.IsAbs(gitDir) {
			gitDir = filepath.Join(path, gitDir)
		}
		headPath = filepath.Join(gitDir, "HEAD")
	}
	data, err := os.ReadFile(headPath)
	if err != nil {
		return ""
	}
	head := strings.TrimSpace(string(data))
	if branch, ok := strings.CutPrefix(head, "ref: refs/heads/"); ok {
		return branch
	}
	if strings.HasPrefix(head, "ref:") {
		return strings.TrimSpace(strings.TrimPrefix(head, "ref:"))
	}
	if len(head) > 7 {
		return head[:7]
	}
	return head
}
