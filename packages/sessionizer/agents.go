package main

import (
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

var agentNames = []string{"opencode2", "opencode", "claude", "codex"}

var agentPatterns = func() []*regexp.Regexp {
	patterns := make([]*regexp.Regexp, len(agentNames))
	for i, name := range agentNames {
		patterns[i] = regexp.MustCompile(`(^|[^a-z0-9])` + regexp.QuoteMeta(name) + `($|[^a-z0-9])`)
	}
	return patterns
}()

// detectAgents names the coding agents a pane runs, from its window name,
// command, title, and the processes under its shell.
func detectAgents(pane Pane) []string {
	text := strings.ToLower(strings.Join([]string{
		pane.WindowName, pane.Command, pane.Title, descendantProcessText(pane.PID),
	}, " "))
	var found []string
	for i, pattern := range agentPatterns {
		if pattern.MatchString(text) {
			found = append(found, agentNames[i])
		}
	}
	return found
}

func descendantProcessText(pid int) string {
	if pid <= 0 {
		return ""
	}
	pending := []int{pid}
	seen := map[int]bool{}
	var fragments []string
	for len(pending) > 0 {
		current := pending[len(pending)-1]
		pending = pending[:len(pending)-1]
		if seen[current] {
			continue
		}
		seen[current] = true
		dir := filepath.Join("/proc", strconv.Itoa(current))
		if comm, err := os.ReadFile(filepath.Join(dir, "comm")); err == nil {
			fragments = append(fragments, strings.TrimSpace(string(comm)))
		}
		if cmdline, err := os.ReadFile(filepath.Join(dir, "cmdline")); err == nil {
			fragments = append(fragments, strings.ReplaceAll(string(cmdline), "\x00", " "))
		}
		children, err := os.ReadFile(filepath.Join(dir, "task", strconv.Itoa(current), "children"))
		if err != nil {
			continue
		}
		for _, field := range strings.Fields(string(children)) {
			if child, err := strconv.Atoi(field); err == nil {
				pending = append(pending, child)
			}
		}
	}
	return strings.Join(fragments, " ")
}
