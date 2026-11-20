# Launcher work runs only while the menu is open

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The launcher service is global and lives for the whole shell session, but its
results matter only while the menu is shown. Its inputs (desktop entries,
niri windows, profiles, clipboard items, remmina connections) change in the
background, and its lookups (qalc, fd, the connection list) are external
processes. Doing that work while closed costs CPU for nothing.

The clipboard service it reads is a separate plugin that the host can replace.
A replacement starts its own `revision` count, which can equal the value the
launcher last saw.

## Decision

The menu being open drives every piece of work. Snapshots are rebuilt lazily,
only when a provider that reads them is active and their source has changed.
qalc and fd only run for the text currently shown. Closing kills any running
lookup, stops every timer, and drops the rows. Source changes that arrive
while closed only mark a snapshot stale.

`pendingWork` reports whether a lookup, debounce, or rescan is scheduled or
running (`appsTimer`, `calcDebounce`, `calcTimeout`, `filesDebounce`,
`filesTimeout`, `connectionsProcess`, `calcProcess`, `filesProcess`). It is
always false while closed. The debounced history write is not counted.

The first app scan of a fresh process can land while the menu already shows an
empty list, so that result reruns the query at once with `Qt.callLater`; later
rescans go through the `appsTimer` debounce.

When the clipboard service object changes and its revision equals the cached
one, the launcher bumps its own clipboard revision so the snapshot is still
rebuilt.

## Consequences

Close must stay the single place that stops processes and timers; a new
timer or process has to be stopped there and added to `pendingWork`.
Tests can rely on `pendingWork` being false after close.

## Where

- `packages/stillsuit-shell/src/plugins/builtin/launcher/Service.qml` (root `Scope`, `pendingWork`, `_ensureClipboard`, the apps watcher handler that calls `_rerun`)
