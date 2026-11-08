package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"syscall"
	"time"
)

// A proxy is a local tmux session whose one pane runs
// `ssh -t <host> sessionizer --proxy-attach`, a tmux client of the remote
// server. The local tmux stays the outer layer: switching to a remote session
// tells that remote client to switch, then moves the local client to the
// proxy. The proxy's key table holds only M-s (see config/.tmux.conf), so
// every other key, the prefix included, reaches the remote tmux.

const proxyKeyTable = "sessionizer-proxy"

// Exit status of --proxy-switch when the host has no live proxy client for
// this origin, so the origin should start a new proxy.
const exitNoProxyClient = 3

type exitStatus int

func (e exitStatus) Error() string { return "exit status " + strconv.Itoa(int(e)) }

func proxySessionName(host string) string {
	return "sessionizer-" + host
}

func sessionSpec(id string) string { return "session:" + id }
func directorySpec(path string) string {
	return "dir:" + path
}

// openRemote shows a remote session or directory through host's proxy.
func openRemote(host, spec string) error {
	origin := localHostname()
	target := "=" + proxySessionName(host)
	exists := sessionExists(target)
	if exists {
		if marker, _ := tmux("show-options", "-qv", "-t", optionTarget(host), "@sessionizer-proxy-host"); marker != host {
			return fmt.Errorf("a session named %s already exists and is not a sessionizer proxy; rename it", proxySessionName(host))
		}
		out, err := run(runOptions{timeout: 20 * time.Second}, masterSSH(host, remoteSessionizer("--proxy-switch", origin, spec))...)
		if err == nil {
			id := strings.TrimSpace(out)
			recordProxyTarget(host, id)
			return switchOrAttach(target)
		}
		var commandErr *commandError
		if errors.As(err, &commandErr) && commandErr.code != exitNoProxyClient && commandErr.code != 255 {
			return fmt.Errorf("could not open %s on %s: %s", strings.TrimPrefix(spec, "dir:"), host, commandErr.message)
		}
	}
	if err := startProxy(host, origin, spec, exists); err != nil {
		return err
	}
	if id, ok := strings.CutPrefix(spec, "session:"); ok {
		recordProxyTarget(host, id)
	}
	return switchOrAttach(target)
}

// startProxy creates host's proxy session, or restarts the pane of a stale
// one in place so a client already showing it never leaves.
func startProxy(host, origin, spec string, replace bool) error {
	target := optionTarget(host)
	command := []string{"ssh", "-t", host, "exec " + remoteSessionizer("--proxy-attach", origin, spec)}
	args := append([]string{"new-session", "-d", "-s", proxySessionName(host), "-c", homeDir()}, command...)
	if replace {
		args = append([]string{"respawn-pane", "-k", "-t", target, "-c", homeDir()}, command...)
	}
	options := [][]string{
		{"key-table", proxyKeyTable},
		{"prefix", "None"},
		{"prefix2", "None"},
		{"status", "off"},
		{"mouse", "off"},
		{"set-titles-string", "#{pane_title}"},
		{"@sessionizer-proxy-host", host},
	}
	for _, option := range options {
		args = append(args, ";", "set-option", "-t", target, option[0], option[1])
	}
	// A failed ssh (no touch, host down) keeps its pane so the error shows.
	args = append(args, ";", "set-option", "-w", "-t", target, "remain-on-exit", "failed")
	_, err := tmux(args...)
	return err
}

// optionTarget names the proxy session exactly for commands, like
// set-option, whose -t is a pane target.
func optionTarget(host string) string {
	return "=" + proxySessionName(host) + ":"
}

func recordProxyTarget(host, id string) {
	if !sessionIDPattern.MatchString(id) {
		return
	}
	tmux("set-option", "-t", optionTarget(host), "@sessionizer-remote-target", id)
	markVisited(host, id)
}

type proxyRecord struct {
	PID int    `json:"pid"`
	TTY string `json:"tty"`
}

func proxyRecordPath(origin string) (string, error) {
	if !hostNamePattern.MatchString(origin) {
		return "", fmt.Errorf("invalid origin host: %q", origin)
	}
	dir, err := privateRuntimeDir("proxy")
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, origin+".json"), nil
}

// resolveSpec turns "session:$N" or "dir:/path" into a session id on this
// host, creating the directory's session if needed.
func resolveSpec(spec string) (string, error) {
	kind, value, _ := strings.Cut(spec, ":")
	switch kind {
	case "session":
		if !sessionIDPattern.MatchString(value) {
			return "", fmt.Errorf("invalid session id: %q", value)
		}
		if !sessionExists(value) {
			return "", fmt.Errorf("session %s no longer exists on %s", value, localHostname())
		}
		return value, nil
	case "dir":
		return ensureDirectorySession(value)
	}
	return "", fmt.Errorf("invalid target: %q", spec)
}

// proxyAttach runs on the remote host as the proxy pane's command. It records
// its terminal so --proxy-switch can find this client, then becomes
// `tmux attach`.
func proxyAttach(origin, spec string) error {
	path, err := proxyRecordPath(origin)
	if err != nil {
		return err
	}
	id, err := resolveSpec(spec)
	if err != nil {
		return err
	}
	tty, err := os.Readlink("/proc/self/fd/0")
	if err != nil || !strings.HasPrefix(tty, "/dev/") {
		return errors.New("--proxy-attach needs a terminal")
	}
	data, err := json.Marshal(proxyRecord{PID: os.Getpid(), TTY: tty})
	if err != nil {
		return err
	}
	if err := writeFileAtomic(path, data, 0o600); err != nil {
		return err
	}
	return execTmux("attach-session", "-t", id)
}

// proxySwitch runs on the remote host: it moves the origin's proxy client to
// the target and prints the session id.
func proxySwitch(origin, spec string) error {
	tty, ok := liveProxyClient(origin)
	if !ok {
		return exitStatus(exitNoProxyClient)
	}
	id, err := resolveSpec(spec)
	if err != nil {
		return err
	}
	if _, err := tmux("switch-client", "-c", tty, "-t", id); err != nil {
		return err
	}
	fmt.Println(id)
	return nil
}

// proxyCurrent runs on the remote host and prints, as inventory JSON, the
// session the origin's proxy client shows. It may differ from the last one
// the picker chose, and may be newer than the origin's cached inventory.
func proxyCurrent(origin string) error {
	tty, ok := liveProxyClient(origin)
	if !ok {
		return exitStatus(exitNoProxyClient)
	}
	id, err := tmux("display-message", "-c", tty, "-p", "#{session_id}")
	if err != nil {
		return err
	}
	state := readLocalState()
	for _, session := range state.sessions {
		if session.ID == id {
			return json.NewEncoder(os.Stdout).Encode(state.inventorySession(session))
		}
	}
	return fmt.Errorf("session %s vanished", id)
}

// proxyShows asks host which session its proxy client shows, over the login
// connection the proxy keeps open.
func proxyShows(host string) (InventorySession, bool) {
	out, err := run(runOptions{timeout: 3 * time.Second}, masterSSH(host, remoteSessionizer("--proxy-current", localHostname()))...)
	var session InventorySession
	if err != nil || json.Unmarshal([]byte(out), &session) != nil || !sessionIDPattern.MatchString(session.ID) {
		return InventorySession{}, false
	}
	return session, true
}

func liveProxyClient(origin string) (string, bool) {
	path, err := proxyRecordPath(origin)
	if err != nil {
		return "", false
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return "", false
	}
	var record proxyRecord
	if json.Unmarshal(data, &record) != nil || record.PID <= 0 {
		return "", false
	}
	if syscall.Kill(record.PID, 0) != nil {
		return "", false
	}
	if tty, err := os.Readlink(fmt.Sprintf("/proc/%d/fd/0", record.PID)); err != nil || tty != record.TTY {
		return "", false
	}
	clients, err := tmux("list-clients", "-F", "#{client_name}")
	if err != nil || !slices.Contains(strings.Split(clients, "\n"), record.TTY) {
		return "", false
	}
	return record.TTY, true
}

func execve(path string, argv, env []string) error {
	return syscall.Exec(path, argv, env)
}
