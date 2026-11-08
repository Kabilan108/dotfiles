// Command sessionizer switches between tmux sessions and project directories
// across the fleet.
package main

import (
	"errors"
	"fmt"
	"os"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/muesli/termenv"
)

const version = "1.0.0"

const usage = `usage: sessionizer [search-path ...]

Pick a tmux session or project directory on this machine or another fleet
host, and switch to it. Search paths override the configured ones.

  -v, --version   print the version
  --init          write the default configuration

Host-to-host commands:
  --inventory                       print this host's sessions and directories
  --ensure-directory-session PATH   create or find PATH's session, print its id
  --proxy-attach ORIGIN TARGET      attach ORIGIN's proxy client to TARGET
  --proxy-switch ORIGIN TARGET      move ORIGIN's proxy client to TARGET
`

func main() {
	err := dispatch(os.Args[1:])
	if err == nil {
		return
	}
	var status exitStatus
	if errors.As(err, &status) {
		os.Exit(int(status))
	}
	fmt.Fprintln(os.Stderr, "sessionizer:", err)
	os.Exit(1)
}

func dispatch(args []string) error {
	if len(args) == 0 || !strings.HasPrefix(args[0], "-") {
		return runPicker(args)
	}
	need := func(count int) error {
		if len(args) != count+1 {
			return fmt.Errorf("%s takes %d argument(s)\n\n%s", args[0], count, usage)
		}
		return nil
	}
	switch args[0] {
	case "-h", "--help":
		fmt.Print(usage)
		return nil
	case "-v", "--version":
		fmt.Println("sessionizer version", version)
		return nil
	case "--init":
		return writeDefaultConfig()
	case "--inventory":
		config, err := loadConfig()
		if err != nil {
			return err
		}
		return printInventory(config)
	case "--ensure-directory-session":
		if err := need(1); err != nil {
			return err
		}
		id, err := ensureDirectorySession(args[1])
		if err != nil {
			return err
		}
		fmt.Println(id)
		return nil
	case "--proxy-attach":
		if err := need(2); err != nil {
			return err
		}
		return proxyAttach(args[1], args[2])
	case "--proxy-switch":
		if err := need(2); err != nil {
			return err
		}
		return proxySwitch(args[1], args[2])
	}
	return fmt.Errorf("unknown option %s\n\n%s", args[0], usage)
}

func runPicker(overrides []string) error {
	config, err := loadConfig()
	if err != nil {
		return err
	}
	localHost := localHostname()
	state := readLocalState()
	favorites := loadFavorites()
	hosts := remoteHosts(config)

	dirs := scanDirectories(config, overrides, state.usedPaths())
	rows := localRows(state, localHost, os.Getenv("FLEET_HOST_HEX"), dirs, favorites)
	caches := map[string]hostCache{}
	for _, host := range hosts {
		caches[host.Name] = readHostCache(host.Name)
		rows = append(rows, remoteRows(host, caches[host.Name], favorites)...)
	}
	if current := currentRowID(state, localHost); current != "" {
		for i := range rows {
			rows[i].Current = rows[i].ID == current
		}
	}
	newHostRank(localHost, hosts).sortRows(rows)

	lipgloss.SetColorProfile(termenv.TrueColor)
	model := newPickerModel(rows, localHost, hosts, caches, favorites)
	if _, err := tea.NewProgram(model, tea.WithAltScreen()).Run(); err != nil {
		return err
	}
	if model.selected == nil {
		return nil
	}
	if err := openRow(*model.selected); err != nil {
		notify(err.Error())
		return exitStatus(1)
	}
	return nil
}

func openRow(row Row) error {
	if !row.Local {
		return openRemote(row.Host, row.spec())
	}
	target := row.Target
	if !row.Session {
		id, err := ensureDirectorySession(row.Target)
		if err != nil {
			return err
		}
		target = id
	}
	return switchOrAttach(target)
}
