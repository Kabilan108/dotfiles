# Tray renders DBusMenus in-shell and ties items to their windows

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Electron and Qt apps create a tray icon only when a StatusNotifierWatcher is
on the session bus. Quickshell renders DBusMenus through `QsMenuOpener`; a
child entry is owned by its parent opener's model, so reusing one opener
destroys the entry being shown. SNI ids are app-chosen ("Slack_status_icon_1",
"discord_status_icon_1", "blueman") while niri knows windows by app_id
("slack", "discord"). Live items are unique `SystemTrayItem` objects but their
`id` strings are not guaranteed unique.

## Decision

The service imports `SystemTray`, which registers the shell as the session's
StatusNotifierWatcher and Host.

The panel keeps one live `QsMenuOpener` per submenu level. Entering a level
rebuilds rows under a cursor that has not moved, so clicks are ignored for
`settleMs` (250 ms) to stop a double-click firing the row that took the spot.
This uses a timestamp, not a `Timer`, because per-output views own no timers.
On a submenu-less app menu, a disabled first row repeating the app's name and
the separator after it are hidden, since the header already names the item.
The submenu header is pinned above the scroll area so the way back stays
reachable. Open windows for the app are listed before the app's own menu,
because getting back to the window is the most common reason to click a tray
icon.

Matching: `appKey` takes the leading identifier token of the SNI id and strips
suffixes such as `status_icon`, `tray`, `indicator`, `applet`, `sni`. A window
matches when its app_id equals the key or the last dotted segment of a
reverse-DNS app_id does. There is no prefix matching, so "steam" does not claim
"steam_app_123". `preferredWindow` picks an already focused window, else one
on the focused output's active workspace, else the first match, so a click
lands where the user already is.

The widget's `ScriptModel` uses `ObjectComparison.Identity`, so each icon keeps
its delegate and decoded image when the filtered list is rebuilt.

## Consequences

Removing the `SystemTray` import removes every Electron and Qt tray icon from
the session. Apps whose SNI id shares no token with their app_id get no window
section.

## Where

- `packages/stillsuit-shell/src/plugins/builtin/tray/Service.qml` (`SystemTray` import, `appKey`, `windowMatches`, `preferredWindow`)
- `packages/stillsuit-shell/src/plugins/builtin/tray/Panel.qml` (`submenuStack`, `settleMs`, `rowHidden`, `backRow`, `windowSection`)
- `packages/stillsuit-shell/src/plugins/builtin/tray/Widget.qml` (Repeater model)
