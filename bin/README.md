# bin

useful bash tools. some of these are used as part of my desktop env others are just clis.

- [battery-watcher](./battery-watcher):
  monitors battery level and sends desktop notifications when low, critical, or fully charged.

- [brightctl](./brightctl):
  controls brightness using acpilight's `xbacklight` utility.

- [cmp-branches](./cmp-branches):
  compares all local git branches with a reference branch, showing ahead and behind commits.

- [git-extract](./git-extract):
  extracts a subdirectory from a remote git repo using sparse checkout, without cloning the whole thing.

- [tkncount](./tkncount):
  counts tokens in stdin using anthropic’s token-counting API.

- [pathurl](./pathurl):
  converts a file path to a file:// url, useful for easy copy-paste.

- [pickers](./pickers):
  uses fzf to select directories or ssh hosts, and opens them in a new or split tmux window.

- [sessionizer](./sessionizer):
  fleet-aware tmux session manager and project directory jumper; the Go source is in [packages/sessionizer](../packages/sessionizer). It lists sessions and unused project directories from reachable machines: the current session first, then favorites, then sessions by when you last visited them, then directories with this machine's first. Rows stay put while the picker is open, and the cursor starts on the previous session. Tab and Shift-Tab cycle the machine filter, Ctrl-S cycles all/sessions/directories, and Ctrl-F (or `f` in normal mode) pins a favorite to the top; favorites live in `~/.local/state/sessionizer/favorites.json`. A remote session shows through a local proxy session (`sessionizer-<host>`) whose pane is a tmux client of that host; M-s inside it opens the local picker, every other key goes to the remote tmux, and the remote prefix + d closes it.

- [volctl](./volctl):
  adjusts audio volume and mute/unmute status with notifications; handles mic as well.

- [flake-update-pr](./flake-update-pr):
  sietch's weekly job. Updates the flake locks in a fresh worktree, builds the hosts, and opens a PR. See `docs/flake-update.md`.

- [flake-lock-verify](./flake-lock-verify):
  run on jacurutu before merging a flake update PR. Checks that each changed input moves forward along the ref it tracks and that its narHash matches the source GitHub or GitLab serves.
