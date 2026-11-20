package main

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/charmbracelet/x/ansi"
)

func TestDirectoryPreviewSessionName(t *testing.T) {
	cases := []struct {
		name     string
		path     string
		sessions string
		local    bool
		want     string
	}{
		{"available basename", "/work/project", "", true, "enter creates session project on local"},
		{"basename collision", "/work/project", "project\x1f$1\n", true, "enter creates session work-project on local"},
		{"parent collision", "/work/project", "project\x1f$1\nwork-project\x1f$2\n", true, "enter creates session work-project-2 on local"},
		{"numeric collision", "/work/project", "project\x1f$1\nwork-project\x1f$2\nwork-project-2\x1f$3\n", true, "enter creates session work-project-3 on local"},
		{"sanitized collision", "/work.dir/project:name", "project_name\x1f$1\n", true, "enter creates session work_dir-project_name on local"},
		{"root directory", "/", "", true, "enter creates session shell on local"},
		{"remote directory", "/work/project", "project\x1f$1\n", false, "enter creates session on remote"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			dir := t.TempDir()
			calls := filepath.Join(dir, "calls")
			script := `#!/bin/sh
printf '%s\n' "$1" >> "$SESSIONIZER_TEST_CALLS"
case "$1" in
list-sessions) printf '%s' "$SESSIONIZER_TEST_SESSIONS" ;;
show-options) printf '%s' '/other/project' ;;
*) exit 1 ;;
esac
`
			if err := os.WriteFile(filepath.Join(dir, "tmux"), []byte(script), 0o700); err != nil {
				t.Fatal(err)
			}
			t.Setenv("PATH", dir)
			t.Setenv("SESSIONIZER_TEST_CALLS", calls)
			t.Setenv("SESSIONIZER_TEST_SESSIONS", c.sessions)
			host := "remote"
			if c.local {
				host = "local"
			}
			_, hint := directoryPreview(Row{Host: host, Target: c.path, Local: c.local}, previewContext{})
			if got := ansi.Strip(hint); got != c.want {
				t.Errorf("hint = %q, want %q", got, c.want)
			}
			if !c.local {
				if _, err := os.Stat(calls); !os.IsNotExist(err) {
					t.Errorf("remote preview queried local tmux: %v", err)
				}
			}
		})
	}
}
