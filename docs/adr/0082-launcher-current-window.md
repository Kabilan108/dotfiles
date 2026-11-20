# Launcher names the window focused before it opened, not niri's focus flags

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The windows provider orders rows alt-tab style: with an empty query the current window moves to the end so the first row is the previous window. That needs to know which window was current when the launcher opened.

niri makes this hard. While a layer surface holds keyboard focus (the launcher menu, or another Stillsuit panel opened before it), niri flags no window as focused and reports a null focus. niri also debounces `focus_timestamp` updates, so right after a focus change the newest stamp can still belong to the previous window. Neither the flag nor the newest stamp reliably names the window the user was in.

Window focus intents run after the menu surface closes, which is too late to report a failure back to the menu.

## Decision

The service captures the focused window as it opens, before the menu takes focus (`_currentWindowId`). When a layer surface already holds focus, it falls back to the compositor adapter's `lastFocusedWindowId` if that window is still open, else null. The adapter keeps `lastFocusedWindowId` across a null focus and across closing other windows, and clears it only when that window closes. A mode switch reopens the menu while it already holds focus, so a reopen keeps what the first open captured.

The provider resolves the current window as `env.currentWindowId` when that window still exists, else the one niri flags focused, else the one with the newest focus timestamp. Items arrive in recency order, so the first item holds the newest stamp. Ordering is most recently focused first and never-focused windows last. With a query, matches within `Matcher.STRONG_MATCH_RATIO` of the best keep strict recency order, the current window included; weaker matches follow by score.

Before running a `window.focus` intent, `activate` checks the window still exists and refuses with "gone" otherwise.

Window rows look up their icon through the desktop entry named by the app id, because a window's app id names its desktop entry far more often than an icon.

Engine tests cover the stamp-only case and the debounced-stamp case. The launcher QML fixture covers the menu taking focus and a panel already holding focus. The d2 compositor fixture covers `lastFocusedWindowId` across null focus and window close.

## Consequences

The capture must happen before the menu surface takes focus. If niri starts flagging focus under layer surfaces or stops debouncing stamps, the fallbacks still give the same answer, and the capture logic can shrink to reading `is_focused`. A window that closes between the existence check and the focus call still fails silently.

## Where

- `packages/stillsuit-shell/src/plugins/builtin/launcher/Service.qml` (`_currentWindowId`, `open`, `activate`, `iconForAppId`)
- `packages/stillsuit-shell/src/plugins/builtin/launcher/model/providers/windows.js` (ordering, `currentOf`)
- `packages/stillsuit-shell/src/tests/launcher/engine.test.js`
- `packages/stillsuit-shell/src/tests/launcher-qml/fixture-shell.qml` (steps "the window focused at open stays current", "with no flagged window the last focused one is current")
- `packages/stillsuit-shell/src/tests/d2-compositor/run-fixtures.sh` (`lastFocusedWindowId` checks)
