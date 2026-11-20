# Sessionizer end-to-end tests run against an isolated three-server tmux fixture

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The picker and proxy sessions span two tmux servers and ssh. Testing them against the user's own tmux would disturb real sessions, and real ssh would need a security key touch.

## Decision

- `e2e/setup.sh BINARY FIXTURE_DIR` builds three tmux servers on private socket directories: driver (the terminal), local (the origin host) and remote (a fleet host reached through a fake ssh that logs its arguments and runs the command against the remote fixture's HOME and XDG directories).
- `e2e/run.sh BINARY` runs the checks against that fixture and never touches the user's own tmux.
- The checks scrape the driver's screen. The picker's list is the column between the popup's border and the preview's border; each row takes two lines, and the first holds the bar, kind icon and name. `first_row` expects the first row's top line in a HERE section right under the rule below the prompt.

## Consequences

- Changes to the row layout, separators or section headers in `view.go` must be matched in `run.sh`'s `list_column`, `row_tops` and `first_row`.

## Where

- `packages/sessionizer/e2e/setup.sh`
- `packages/sessionizer/e2e/run.sh` (`list_column`, `row_tops`, `first_row`)
