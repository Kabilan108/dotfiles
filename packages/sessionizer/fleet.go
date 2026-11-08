package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
	"syscall"
	"time"
)

type FleetHost struct {
	Name    string
	Color   string
	Address string
}

var hostNamePattern = regexp.MustCompile(`^[A-Za-z0-9_-]+$`)

func readFleetHosts() []FleetHost {
	data, err := os.ReadFile(fleetHostsPath())
	if err != nil {
		return nil
	}
	var hosts []FleetHost
	for _, line := range strings.Split(string(data), "\n") {
		fields := strings.Split(line, "\t")
		if len(fields) < 3 || !hostNamePattern.MatchString(fields[0]) {
			continue
		}
		hosts = append(hosts, FleetHost{
			Name:    fields[0],
			Color:   fields[1],
			Address: fields[2],
		})
	}
	return hosts
}

func localHostname() string {
	name, err := os.Hostname()
	if err != nil {
		return "localhost"
	}
	name, _, _ = strings.Cut(name, ".")
	return name
}

// remoteHosts returns the configured remote hosts this machine can reach,
// in fleet order. A machine without an agent key reaches none.
func remoteHosts(config Config) []FleetHost {
	keyPath := filepath.Join(homeDir(), ".ssh", "agent-"+localHostname())
	if _, err := os.Stat(keyPath); err != nil {
		return nil
	}
	local := localHostname()
	var result []FleetHost
	for _, host := range readFleetHosts() {
		if host.Name != local && slices.Contains(config.RemoteHosts, host.Name) {
			result = append(result, host)
		}
	}
	return result
}

// remoteSessionizer is the command another host runs. deploy-gate on gated
// hosts allows exactly `"$HOME/bin/sessionizer" --inventory`, so keep that
// spelling. SESSIONIZER_REMOTE_PROGRAM swaps in another build on the remote
// side for testing; gated hosts then refuse the inventory.
func remoteSessionizer(args ...string) string {
	program := `"$HOME/bin/sessionizer"`
	if override := os.Getenv("SESSIONIZER_REMOTE_PROGRAM"); override != "" {
		program = override
	}
	return program + " " + shellJoin(args)
}

func agentSSH(host, remote string) []string {
	return []string{
		"ssh",
		"-o", "BatchMode=yes",
		"-o", "ConnectTimeout=2",
		host + "-agent",
		remote,
	}
}

// masterSSH runs remote over an already open login connection and fails
// rather than authenticate, so it never asks for a security key touch.
func masterSSH(host, remote string) []string {
	return []string{
		"ssh", "-T", "-n",
		"-o", "ControlMaster=no",
		"-o", "BatchMode=yes",
		"-o", "PubkeyAuthentication=no",
		"-o", "ConnectTimeout=2",
		host,
		remote,
	}
}

const (
	statusOnline     = "online"
	statusOffline    = "offline"
	statusConnecting = "connecting"
)

type hostCache struct {
	Status      string               `json:"status"`
	Updated     int64                `json:"updated,omitempty"`
	Sessions    []InventorySession   `json:"sessions"`
	Directories []InventoryDirectory `json:"directories"`
}

func hostCachePath(host string) string {
	return filepath.Join(remoteCacheDir(), host+".json")
}

func readHostCache(host string) hostCache {
	empty := hostCache{Status: statusConnecting}
	data, err := os.ReadFile(hostCachePath(host))
	if err != nil {
		return empty
	}
	var cache hostCache
	if err := json.Unmarshal(data, &cache); err != nil || cache.Sessions == nil {
		return empty
	}
	return cache
}

func writeHostCache(host string, cache hostCache) error {
	data, err := json.Marshal(cache)
	if err != nil {
		return err
	}
	return writeFileAtomic(hostCachePath(host), data, 0o600)
}

// refreshHost fetches host's inventory over the agent key and caches it. It
// returns the cache it wrote, or the previous one marked offline.
func refreshHost(host FleetHost) hostCache {
	if err := os.MkdirAll(remoteCacheDir(), 0o755); err != nil {
		return readHostCache(host.Name)
	}
	lock, err := os.OpenFile(filepath.Join(remoteCacheDir(), host.Name+".lock"), os.O_CREATE|os.O_WRONLY, 0o600)
	if err != nil {
		return readHostCache(host.Name)
	}
	defer lock.Close()
	if err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX); err != nil {
		return readHostCache(host.Name)
	}
	defer syscall.Flock(int(lock.Fd()), syscall.LOCK_UN)

	previous := readHostCache(host.Name)
	if previous.Status == statusOnline && time.Now().Unix()-previous.Updated < 3 {
		return previous
	}
	out, err := run(runOptions{timeout: 15 * time.Second}, agentSSH(host.Name, remoteSessionizer("--inventory"))...)
	var inventory Inventory
	if err == nil {
		err = json.Unmarshal([]byte(out), &inventory)
	}
	if err != nil || inventory.Sessions == nil {
		previous.Status = statusOffline
		if previous.Sessions == nil {
			previous.Sessions = []InventorySession{}
		}
		writeHostCache(host.Name, previous)
		return previous
	}
	if inventory.Directories == nil {
		inventory.Directories = []InventoryDirectory{}
	}
	cache := hostCache{
		Status:      statusOnline,
		Updated:     time.Now().Unix(),
		Sessions:    inventory.Sessions,
		Directories: inventory.Directories,
	}
	writeHostCache(host.Name, cache)
	return cache
}

// markVisited bumps a cached remote session to now, so the next picker
// orders it correctly before its refresh lands.
func markVisited(host, sessionID string) {
	cache := readHostCache(host)
	now := time.Now().Unix()
	changed := false
	for i := range cache.Sessions {
		if cache.Sessions[i].ID == sessionID {
			cache.Sessions[i].LastAttached = now
			cache.Sessions[i].Activity = now
			changed = true
		}
	}
	if changed {
		writeHostCache(host, cache)
	}
}
