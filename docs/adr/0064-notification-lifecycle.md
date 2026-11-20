# Notification rows follow a fixed lifecycle across hover, quiet mode and restarts

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

`NotificationService` keeps on-screen rows (`popups`), rows held during quiet mode (`held`), and arrivals queued behind a hovered deck. State persists to a file whose schema has changed over time. Settings cross a QML property boundary as `QVariantList`, which fails `Array.isArray` in Qt's JS engine while still iterating like an array. The host also raises its own notices, such as containment reports and workbench fixtures.

## Decision

- Arrivals wait in `queuedArrivals` while the pointer is over a deck, so nothing moves under it.
- Held rows keep their live notification reference, so their actions still work when they replay. Replay runs oldest first so the newest lands on top, and also runs at hydrate time for quiet mode that ended while the shell was down.
- Transient rows and stack-tagged status cards (volume, brightness) are not held for replay (`silenced-ephemeral`).
- A `replaces_id` update restarts the display lifetime, even when only the body, an action label or the timeout changed.
- Cards with buttons stay for `max(normalTimeoutMs, actionTimeoutMs)`, 10 s by default, so the buttons can be reached.
- `NotificationLayout.group` takes rows newest first and returns decks ordered by their newest row.
- `parseState` reads every schema the file has had, including the old `dnd` flag; version 2 history, finite snoozes and early version 3 per-source mutes are dropped.
- `listValue` copies any array-like value into a JS array.
- `HostNotice` has the same shape as a `Quickshell.Services.Notifications` object, so the service tracks host notices without a D-Bus round trip.

## Consequences

Callers of `group` must pass newest-first rows. Older state files load without their dropped features. Every settings list read in the policy must go through `listValue`.

## Where

- `packages/stillsuit-shell/src/services/NotificationService.qml` (`queuedArrivals`, `hold`, `replayHeld`, hydrate, the `replaces_id` update path)
- `packages/stillsuit-shell/src/services/NotificationPolicy.js` (`listValue`, `durationFor`, `quietClass`)
- `packages/stillsuit-shell/src/services/NotificationLayout.js` (`group`)
- `packages/stillsuit-shell/src/services/NotificationModel.js` (`parseState`)
- `packages/stillsuit-shell/src/core/HostNotice.qml`
