# Helper-backed services leave external state to their workers

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The meeting-minutes worker owns its durable job queue (`jobs.json`) and status; a discard goes through the meeting-minutes helper, which rewrites `jobs.json`, and `refresh()` reloads from that file. A bug that kept the job in the durable source would bring it back on the next refresh. The recorder helper owns recordings and publishing. The shell services project that state and offer a few user actions.

## Decision

- `MeetingService` only reads the worker's status and bounded queue snapshot. It requests a retry or discard of a failed job only on an explicit user action, through the same typed helper action process, and never while loading state or recovering after a reload. It never edits `jobs.json` itself.
- `RecordingService.publish` runs on its own process, so the helper-backed actions (rename, dismiss) stay available while an upload is in flight.
- The recording-meetings fixture's fake keeps its in-memory jobs array as the durable source and makes `refresh()` a no-op, so calling it after a discard shows whether the discarded job comes back. `run.sh` discards a failed job, refreshes, and checks it stays gone while the unrelated completed job remains.

## Consequences

A shell reload cannot duplicate or lose meeting jobs. Discarding a job depends on the worker helper being configured. Changes to how discard is stored must keep the helper's rewrite as the single source of truth.

## Where

- `packages/stillsuit-shell/src/services/MeetingService.qml` (`retry`, `discard`, `refresh`, `_runAction`)
- `packages/stillsuit-shell/src/services/RecordingService.qml` (`publish`)
- `packages/stillsuit-shell/src/tests/recording-meetings/fixture-shell.qml` (fake meeting service `refresh`)
- `packages/stillsuit-shell/src/tests/recording-meetings/run.sh`
