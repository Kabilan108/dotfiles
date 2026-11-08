package main

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

const fieldSeparator = "\x1f"

type commandError struct {
	command []string
	message string
	code    int
}

func (e *commandError) Error() string {
	return fmt.Sprintf("%s: %s", shellJoin(e.command), e.message)
}

type runOptions struct {
	timeout time.Duration
	env     []string
	stdin   *os.File
	stderr  *os.File
}

// run executes a command and returns its stdout. A non-zero exit is an error
// that carries stderr.
func run(options runOptions, command ...string) (string, error) {
	timeout := options.timeout
	if timeout == 0 {
		timeout = 10 * time.Second
	}
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, command[0], command[1:]...)
	if options.env != nil {
		cmd.Env = options.env
	}
	if options.stdin != nil {
		cmd.Stdin = options.stdin
	}
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	if options.stderr != nil {
		cmd.Stderr = options.stderr
	} else {
		cmd.Stderr = &stderr
	}
	err := cmd.Run()
	if ctx.Err() != nil {
		return stdout.String(), &commandError{command, "timed out", -1}
	}
	if err != nil {
		message := strings.TrimSpace(stderr.String())
		if message == "" {
			message = strings.TrimSpace(stdout.String())
		}
		if message == "" {
			message = err.Error()
		}
		code := -1
		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) {
			code = exitErr.ExitCode()
		}
		return stdout.String(), &commandError{command, message, code}
	}
	return stdout.String(), nil
}

func tmux(args ...string) (string, error) {
	out, err := run(runOptions{}, append([]string{"tmux"}, args...)...)
	return strings.TrimRight(out, "\n"), err
}

func insideTmux() bool {
	return os.Getenv("TMUX") != ""
}

func tmuxDisplay(format string) string {
	if !insideTmux() {
		return ""
	}
	out, err := tmux("display-message", "-p", format)
	if err != nil {
		return ""
	}
	return out
}

func notify(message string) {
	fmt.Fprintln(os.Stderr, "sessionizer:", message)
	if insideTmux() {
		tmux("display-message", "sessionizer: "+message)
	}
}

type tmuxSession struct {
	ID             string
	Name           string
	Windows        string
	Attached       bool
	RegisteredPath string
	SessionPath    string
	LastAttached   int64
	Activity       int64
	Created        int64
	ProxyHost      string
	RemoteTarget   string
}

func (s tmuxSession) Path() string {
	if s.RegisteredPath != "" {
		return s.RegisteredPath
	}
	return s.SessionPath
}

// Recency orders sessions by when you last switched to them. A session nobody
// has attached yet counts from its creation.
func (s tmuxSession) Recency() int64 {
	if s.LastAttached > 0 {
		return s.LastAttached
	}
	return s.Created
}

var sessionFormat = strings.Join([]string{
	"#{session_id}",
	"#{session_name}",
	"#{session_windows}",
	"#{session_attached}",
	"#{@sessionizer-path}",
	"#{session_path}",
	"#{session_last_attached}",
	"#{session_activity}",
	"#{session_created}",
	"#{@sessionizer-proxy-host}",
	"#{@sessionizer-remote-target}",
}, fieldSeparator)

func parseInt(value string) int64 {
	number, _ := strconv.ParseInt(strings.TrimSpace(value), 10, 64)
	return number
}

// listTmuxSessions returns every session, proxies included. An absent tmux
// server is an empty list.
func listTmuxSessions() []tmuxSession {
	out, err := tmux("list-sessions", "-F", sessionFormat)
	if err != nil {
		return nil
	}
	return parseTmuxSessions(out)
}

func parseTmuxSessions(out string) []tmuxSession {
	var sessions []tmuxSession
	for _, line := range strings.Split(out, "\n") {
		fields := strings.Split(line, fieldSeparator)
		if len(fields) != 11 {
			continue
		}
		sessions = append(sessions, tmuxSession{
			ID:             fields[0],
			Name:           fields[1],
			Windows:        fields[2],
			Attached:       fields[3] != "" && fields[3] != "0",
			RegisteredPath: fields[4],
			SessionPath:    fields[5],
			LastAttached:   parseInt(fields[6]),
			Activity:       parseInt(fields[7]),
			Created:        parseInt(fields[8]),
			ProxyHost:      fields[9],
			RemoteTarget:   fields[10],
		})
	}
	return sessions
}

type Pane struct {
	SessionID    string   `json:"-"`
	WindowIndex  string   `json:"window_index"`
	WindowName   string   `json:"window_name"`
	WindowActive bool     `json:"window_active"`
	PaneIndex    string   `json:"pane_index"`
	PaneActive   bool     `json:"pane_active"`
	PID          int      `json:"-"`
	Command      string   `json:"command"`
	Path         string   `json:"path"`
	Title        string   `json:"title"`
	Agents       []string `json:"agents,omitempty"`
}

var paneFormat = strings.Join([]string{
	"#{session_id}",
	"#{window_index}",
	"#{window_name}",
	"#{window_active}",
	"#{pane_index}",
	"#{pane_active}",
	"#{pane_pid}",
	"#{pane_current_command}",
	"#{pane_current_path}",
	"#{pane_title}",
}, fieldSeparator)

// listAllPanes returns every pane on the server keyed by session id, with the
// coding agents running in each.
func listAllPanes() map[string][]Pane {
	out, err := tmux("list-panes", "-a", "-F", paneFormat)
	if err != nil {
		return map[string][]Pane{}
	}
	result := map[string][]Pane{}
	for _, line := range strings.Split(out, "\n") {
		fields := strings.SplitN(line, fieldSeparator, 10)
		if len(fields) != 10 {
			continue
		}
		pid, _ := strconv.Atoi(fields[6])
		pane := Pane{
			SessionID:    fields[0],
			WindowIndex:  fields[1],
			WindowName:   fields[2],
			WindowActive: fields[3] == "1",
			PaneIndex:    fields[4],
			PaneActive:   fields[5] == "1",
			PID:          pid,
			Command:      fields[7],
			Path:         fields[8],
			Title:        fields[9],
		}
		pane.Agents = detectAgents(pane)
		result[pane.SessionID] = append(result[pane.SessionID], pane)
	}
	return result
}

var unsafeSessionChars = regexp.MustCompile(`[:.]`)

func sessionIDsByName() map[string]string {
	out, err := tmux("list-sessions", "-F", "#{session_name}"+fieldSeparator+"#{session_id}")
	result := map[string]string{}
	if err != nil {
		return result
	}
	for _, line := range strings.Split(out, "\n") {
		name, id, ok := strings.Cut(line, fieldSeparator)
		if ok {
			result[name] = id
		}
	}
	return result
}

// sessionNameForDirectory picks the directory's basename, or parent-basename
// when another directory already holds that name.
func sessionNameForDirectory(path string, sessions map[string]string) string {
	base := unsafeSessionChars.ReplaceAllString(filepath.Base(path), "_")
	if base == "" || base == "/" {
		base = "shell"
	}
	id, taken := sessions[base]
	if !taken {
		return base
	}
	registered, _ := tmux("show-options", "-qv", "-t", id, "@sessionizer-path")
	if registered == "" || sameDirectory(registered, path) {
		return base
	}
	parent := unsafeSessionChars.ReplaceAllString(filepath.Base(filepath.Dir(path)), "_")
	candidate := base
	if parent != "" && parent != "/" {
		candidate = parent + "-" + base
	}
	stem := candidate
	for suffix := 2; ; suffix++ {
		if _, exists := sessions[candidate]; !exists {
			return candidate
		}
		candidate = fmt.Sprintf("%s-%d", stem, suffix)
	}
}

func sameDirectory(a, b string) bool {
	ra, errA := filepath.EvalSymlinks(a)
	rb, errB := filepath.EvalSymlinks(b)
	return errA == nil && errB == nil && ra == rb
}

// ensureDirectorySession returns the id of the session for path, creating it
// and running its .sessionizer script if there is none.
func ensureDirectorySession(pathValue string) (string, error) {
	path, err := filepath.Abs(expandUser(pathValue))
	if err != nil {
		return "", err
	}
	if resolved, err := filepath.EvalSymlinks(path); err == nil {
		path = resolved
	}
	if info, err := os.Stat(path); err != nil || !info.IsDir() {
		return "", fmt.Errorf("not a directory: %s", path)
	}
	sessions := sessionIDsByName()
	name := sessionNameForDirectory(path, sessions)
	if id, ok := sessions[name]; ok {
		return id, nil
	}
	id, err := tmux("new-session", "-d", "-P", "-F", "#{session_id}", "-s", name, "-c", path)
	if err != nil {
		return "", err
	}
	if _, err := tmux("set-option", "-t", id, "@sessionizer-path", path); err != nil {
		return "", err
	}
	hydrate(id, path)
	return id, nil
}

func hydrate(session, path string) {
	script := filepath.Join(path, ".sessionizer")
	if info, err := os.Stat(script); err != nil || !info.Mode().IsRegular() {
		script = filepath.Join(homeDir(), ".sessionizer")
	}
	if info, err := os.Stat(script); err == nil && info.Mode().IsRegular() {
		tmux("send-keys", "-t", session, "source "+shellQuote(script), "Enter")
	}
}

func sessionExists(target string) bool {
	_, err := tmux("has-session", "-t", target)
	return err == nil
}

// switchOrAttach moves this tmux client to target, or attaches to it when the
// picker runs outside tmux.
func switchOrAttach(target string) error {
	if insideTmux() {
		args := []string{"switch-client"}
		if client := tmuxDisplay("#{client_name}"); client != "" {
			args = append(args, "-c", client)
		}
		_, err := tmux(append(args, "-t", target)...)
		return err
	}
	return execTmux("attach-session", "-t", target)
}

func execTmux(args ...string) error {
	path, err := exec.LookPath("tmux")
	if err != nil {
		return err
	}
	env := withoutEnv(os.Environ(), "TMUX", "TMUX_PANE")
	return execve(path, append([]string{"tmux"}, args...), env)
}

func withoutEnv(env []string, names ...string) []string {
	var result []string
outer:
	for _, entry := range env {
		for _, name := range names {
			if strings.HasPrefix(entry, name+"=") {
				continue outer
			}
		}
		result = append(result, entry)
	}
	return result
}

var shellSafe = regexp.MustCompile(`^[A-Za-z0-9_@%+=:,./-]+$`)

func shellQuote(value string) string {
	if value == "" {
		return "''"
	}
	if shellSafe.MatchString(value) {
		return value
	}
	return "'" + strings.ReplaceAll(value, "'", `'"'"'`) + "'"
}

func shellJoin(args []string) string {
	quoted := make([]string, len(args))
	for i, arg := range args {
		quoted[i] = shellQuote(arg)
	}
	return strings.Join(quoted, " ")
}
