# Route interactive Bash sessions to tmux over SSH and niri on tty1

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Interactive SSH terminals should land in a persistent tmux session. Remote tools may start an interactive login shell without allocating a terminal, and those must not exec tmux. On the console, niri should start only on tty1, leaving tty2 to tty6 for troubleshooting. `XDG_VTNR` alone is not a reliable signal, because it leaks into tmux panes started without `DISPLAY`.

## Decision

- `.bashrc` execs `tmux new-session -A -s main` only when `SSH_TTY` is set, `TMUX` and `NO_TMUX` are unset, and tmux exists. `rawssh` sets `NO_TMUX=1` to opt out.
- It execs `niri-session` only when `DISPLAY`, `WAYLAND_DISPLAY`, `TMUX` and `SSH_CONNECTION` are unset and `tty` prints `/dev/tty1`. Using exec means exiting the compositor logs out.

## Consequences

Checks must keep keying on `SSH_TTY` and the real tty device, not `SSH_CONNECTION` or `XDG_VTNR`.

## Where

- `config/.bashrc` (SSH tmux attach, `rawssh`, niri autostart block)
