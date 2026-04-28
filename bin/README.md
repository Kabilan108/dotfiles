# bin

useful bash tools. some of these are used as part of my desktop env others are just clis.

- [battery-watcher](./battery-watcher):
  monitors battery level and sends desktop notifications when low, critical, or fully charged.

- [brightctl](./brightctl):
  controls brightness using the `light` utility, with notify feedback.

- [cmp-branches](./cmp-branches):
  compares all local git branches with a reference branch, showing ahead and behind commits.

- [discord-notify](./discord-notify):
  sends scriptable Discord webhook notifications from stdin, with status colors for cron jobs and local agents.

- [git-extract](./git-extract):
  extracts a subdirectory from a remote git repo using sparse checkout, without cloning the whole thing.

- [tkncount](./tkncount):
  counts tokens in stdin using anthropic’s token-counting API.

- [open-nvim](./open-nvim):
  launches neovim inside a ghostty terminal.

- [patch-snaps](./patch-snaps):
  fixes exec lines in snap application desktop files for better integration. handles a bug i've been having with snaps in ubuntu 24.04 lts

- [pathurl](./pathurl):
  converts a file path to a file:// url, useful for easy copy-paste.

- [pickers](./pickers):
  uses fzf to select directories or ssh hosts, and opens them in a new or split tmux window.

- [sessionizer](./sessionizer):
  quick tmux session manager and directory jumper, integrates with fzf. inspired by [ThePrimeagen](https://github.com/ThePrimeagen/tmux-sessionizer/tree/master)

- [set-wallpaper](./set-wallpaper):
  sets wallpaper using the `feh` utility, loading the path from a variable.

- [start-polybar](./start-polybar):
  launches polybar status bar with proper configuration.

- [claude-check](./claude-check):
  utility for checking claude code integration.

- [ws](./ws):
  workspace management utility.

- [volctl](./volctl):
  adjusts audio volume and mute/unmute status with notifications; handles mic as well.
