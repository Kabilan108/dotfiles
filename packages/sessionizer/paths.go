package main

import (
	"fmt"
	"os"
	"os/user"
	"path/filepath"
	"strings"
)

func homeDir() string {
	if home := os.Getenv("HOME"); home != "" {
		return home
	}
	if current, err := user.Current(); err == nil {
		return current.HomeDir
	}
	return "/"
}

func xdgDir(variable string, fallback ...string) string {
	if value := os.Getenv(variable); value != "" {
		return value
	}
	return filepath.Join(append([]string{homeDir()}, fallback...)...)
}

func configPath() string {
	if value := os.Getenv("SESSIONIZER_CONFIG"); value != "" {
		return value
	}
	return filepath.Join(xdgDir("XDG_CONFIG_HOME", ".config"), "sessionizer", "config.json")
}

func cacheDir() string {
	return filepath.Join(xdgDir("XDG_CACHE_HOME", ".cache"), "sessionizer")
}

func remoteCacheDir() string {
	return filepath.Join(cacheDir(), "remotes")
}

func fleetHostsPath() string {
	return filepath.Join(xdgDir("XDG_CONFIG_HOME", ".config"), "fleet", "hosts")
}

func favoritesPath() string {
	return filepath.Join(xdgDir("XDG_STATE_HOME", ".local", "state"), "sessionizer", "favorites.json")
}

// privateRuntimeDir returns a 0700 directory under XDG_RUNTIME_DIR that only
// this user owns, creating it if needed.
func privateRuntimeDir(name string) (string, error) {
	runtime := os.Getenv("XDG_RUNTIME_DIR")
	if runtime == "" {
		runtime = fmt.Sprintf("/run/user/%d", os.Getuid())
	}
	path := filepath.Join(runtime, "sessionizer", name)
	if err := os.MkdirAll(path, 0o700); err != nil {
		return "", err
	}
	info, err := os.Lstat(path)
	if err != nil {
		return "", err
	}
	if info.Mode()&os.ModeSymlink != 0 || !ownedByMe(info) {
		return "", fmt.Errorf("unsafe runtime directory: %s", path)
	}
	if err := os.Chmod(path, 0o700); err != nil {
		return "", err
	}
	return path, nil
}

func expandUser(path string) string {
	if path == "~" {
		return homeDir()
	}
	if strings.HasPrefix(path, "~/") {
		return filepath.Join(homeDir(), path[2:])
	}
	return path
}

func abbreviatePath(path string) string {
	home := homeDir()
	if path == home {
		return "~"
	}
	if strings.HasPrefix(path, home+"/") {
		return "~" + path[len(home):]
	}
	return path
}

func writeFileAtomic(path string, data []byte, perm os.FileMode) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	temporary, err := os.CreateTemp(filepath.Dir(path), "."+filepath.Base(path)+".*.tmp")
	if err != nil {
		return err
	}
	name := temporary.Name()
	_, writeErr := temporary.Write(data)
	closeErr := temporary.Close()
	if writeErr != nil || closeErr != nil {
		os.Remove(name)
		if writeErr != nil {
			return writeErr
		}
		return closeErr
	}
	if err := os.Chmod(name, perm); err != nil {
		os.Remove(name)
		return err
	}
	return os.Rename(name, path)
}
