# rebuild's review function returns explicitly on every failure

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

`bin/rebuild` calls `review` from an `if`. Bash disables `errexit` inside a function called from a condition, so a failing command inside `review` would not stop it.

## Decision

Every command in `review` and `pin` that can fail ends with `|| return 1`. `review` returns 0 to build, and pins the tag only when a pushed fleet tag covers the whole build.

## Consequences

New commands in `review` need their own `|| return 1`; `set -e` does not cover them.

## Where

- `bin/rebuild` (`review`, `pin`)
