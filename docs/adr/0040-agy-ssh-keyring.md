# Hide SSH variables from agy when a local session bus exists

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

agy skips the system keyring whenever `SSH_*` environment variables are set, even when the user D-Bus session bus and an unlocked gnome-keyring are reachable. SSH and tmux sessions then lose the keyring sign-in that the desktop and T3 Code use.

## Decision

The `agy` Bash function checks for `$XDG_RUNTIME_DIR/bus`. When the socket exists, it runs agy with `SSH_CONNECTION`, `SSH_CLIENT` and `SSH_TTY` unset and `DBUS_SESSION_BUS_ADDRESS` defaulted to that socket. Otherwise it runs agy unchanged.

## Consequences

If agy stops gating keyring use on `SSH_*`, the wrapper can go. Hosts without a user session bus keep agy's default behaviour.

## Where

- `config/.bashrc` (`agy`)
