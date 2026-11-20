# agent-run reads run records under the launch lock and resumes Codex by id

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

`agent-run` launches workers in tmux and records each run in `run.json`, with completion written to `exit.json`. A reader could see a record as running before launch finishes, and a worker can write `exit.json` while the reader is checking `tmux has-session`. Codex's `--last` resumes the most recent session rather than a named one.

## Decision

- `read_record` takes a shared lock on `.start.lock`, which launch holds exclusively, so no reader observes a running record before launch completes.
- After `has-session` reports the session gone, `read_record` checks `exit.json` again before treating the run as interrupted, since the worker may have saved completion during the check.
- Codex resumes pass config flags (`-c ...`) to `exec`/`resume`, which accept them, and always name the session id. `--last` is never used.

## Consequences

Any new reader of run state must take the same shared lock.

## Where

- `bin/agent-run` (`read_record`, the Codex argument builder)
