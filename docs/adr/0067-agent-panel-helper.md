# Agent panel helper works around Ghostty and tmux process quirks

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

`stillsuit-agent-panel` opens a Ghostty window that runs `$SELF attach`, and it serializes actions with `flock` on fd 9 (`agent-panel.lock` in the runtime directory). Ghostty 1.3 prepends `--posix` to the command it starts in a new window. Any `tmux` call can start a tmux server, and a server started by the helper inherits the helper's open file descriptors, including the lock.

## Decision

- The argument loop drops every leading `--posix` before parsing the action, and `GHOSTTY_COMMAND` uses the `direct:` form.
- A `tmux` shell function wraps every call as `command tmux "$@" 9>&-`, so no server, including one started by a query, keeps the lock open after the helper exits.

## Consequences

If the `9>&-` wrapper is bypassed, a newly started tmux server holds the lock, and later panel actions time out after 10 s with exit 75. The `--posix` stripping can go once Ghostty stops prepending it.

## Where

- `packages/stillsuit-shell/bin/stillsuit-agent-panel` (`GHOSTTY_COMMAND`, the `--posix` loop, `tmux()`)
