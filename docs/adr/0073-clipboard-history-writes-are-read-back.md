# Clipboard history writes are verified by reading them back

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Blob removal must never run before a history without the removed entries is on
disk. Quickshell's `FileView` reports a failed atomic commit (ENOSPC on flush)
as saved. It also keeps the text of a failed save as if it were on disk and
skips a later save of the same text.

## Decision

`_writeDurably` writes the history synchronously and reads it back.
`historyMatches` compares only entry shas, order and pending-removal decision
times, so text that changed in a UTF-8 round trip still matches. After a
failed save `_historyCacheStale` is set, and the next write resets the
`FileView` path to drop its cached text. Every change either restarts
`persistTimer` or writes at once, so `_flushNow` only has work when the timer
runs or a write failed.

## Consequences

Remove the read-back once `FileView` reports failed commits and stops caching
failed text. The README's crash-safety guarantees depend on this check.

## Where

- `packages/stillsuit-shell/src/plugins/builtin/clipboard/Service.qml` (`_writeDurably`, `_historyCacheStale`, `_flushNow`)
- `packages/stillsuit-shell/src/plugins/builtin/clipboard/ClipboardModel.js` (`historyMatches`)
- `packages/stillsuit-shell/src/plugins/builtin/clipboard/README.md` (Removal)
