# acu discards wl-copy's output instead of capturing it

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

`wl-copy` forks a daemon that keeps serving the clipboard, and the daemon inherits the parent's stdout and stderr. If the caller captures those pipes, it waits for an EOF that arrives only when the daemon exits.

## Decision

`clipboard_restore` and the clipboard clear in `acu shot` run `wl-copy` with stdout and stderr sent to `/dev/null`.

## Consequences

acu never sees wl-copy's error output. Any new `wl-copy` call in acu must also avoid capturing output, or the command hangs.

## Where

- `agents/skills/niri-computer-use/scripts/acu` (`clipboard_restore`, `shot_window`)
