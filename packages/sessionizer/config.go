package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"syscall"
)

type Config struct {
	SearchPaths []string
	MaxDepth    int
	Ignore      []string
	RemoteHosts []string
}

var defaultConfig = Config{
	SearchPaths: []string{"~/", "~/repos", "~/gists"},
	MaxDepth:    1,
	Ignore:      []string{"node_modules", ".git", "target"},
	RemoteHosts: []string{"sietch"},
}

type configFile struct {
	SearchPaths *[]string `json:"search_paths"`
	MaxDepth    *int      `json:"max_depth"`
	Ignore      []string  `json:"ignore"`
	RemoteHosts []string  `json:"remote_hosts"`
}

func loadConfig() (Config, error) {
	path := configPath()
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return defaultConfig, nil
	}
	if err != nil {
		return Config{}, err
	}
	var raw configFile
	if err := json.Unmarshal(data, &raw); err != nil {
		return Config{}, fmt.Errorf("invalid configuration in %s: %w", path, err)
	}
	if raw.SearchPaths == nil {
		return Config{}, fmt.Errorf("invalid configuration in %s: search_paths is required", path)
	}
	config := Config{
		SearchPaths: *raw.SearchPaths,
		MaxDepth:    1,
		Ignore:      raw.Ignore,
		RemoteHosts: raw.RemoteHosts,
	}
	if raw.MaxDepth != nil {
		config.MaxDepth = *raw.MaxDepth
	}
	if config.MaxDepth < 0 {
		return Config{}, errors.New("max_depth must be non-negative")
	}
	return config, nil
}

func writeDefaultConfig() error {
	path := configPath()
	if _, err := os.Stat(path); err == nil {
		return fmt.Errorf("configuration already exists: %s", path)
	}
	payload, err := json.MarshalIndent(map[string]any{
		"search_paths": defaultConfig.SearchPaths,
		"max_depth":    defaultConfig.MaxDepth,
		"ignore":       defaultConfig.Ignore,
		"remote_hosts": defaultConfig.RemoteHosts,
	}, "", "  ")
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	if err := os.WriteFile(path, append(payload, '\n'), 0o644); err != nil {
		return err
	}
	fmt.Println("wrote", path)
	return nil
}

var searchPathDepth = regexp.MustCompile(`^(.+):([0-9]+)$`)

// parseSearchPath reads "path" or "path:depth".
func parseSearchPath(value string, defaultDepth int) (string, int) {
	if match := searchPathDepth.FindStringSubmatch(value); match != nil {
		depth, err := strconv.Atoi(match[2])
		if err == nil {
			return expandUser(match[1]), depth
		}
	}
	return expandUser(value), defaultDepth
}

func ownedByMe(info os.FileInfo) bool {
	stat, ok := info.Sys().(*syscall.Stat_t)
	return ok && int(stat.Uid) == os.Getuid()
}
