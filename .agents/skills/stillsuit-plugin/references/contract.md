# Plugin contract reference

Condensed from `docs/host-contract.md` and `schemas/manifest.v1.json`, which
remain authoritative.

## Manifest

```json
{
  "schemaVersion": 1,
  "id": "stillsuit.<name>",
  "name": "Human name",
  "description": "One sentence.",
  "version": "1.0.0",
  "apiVersion": "1",
  "kinds": ["service", "bar-widget", "panel"],
  "entryPoints": { "service": "Service.qml", "barWidget": "Widget.qml", "panel": "Panel.qml" },
  "scope": { "service": "global", "barWidget": "per-output", "panel": "per-output" },
  "barWidget": { "defaultSection": "right", "allowMultiple": false, "order": 50 },
  "dependencies": ["stillsuit.power"],
  "capabilities": ["some-authority"],
  "keepLoaded": true
}
```

- `kinds`: `bar`, `bar-widget`, `service`, `panel`, `overlay`, `menu`. Every
  kind needs a matching `entryPoints` and `scope` entry.
- `scope`: services are always `global`; bar widgets always `per-output`;
  panels, overlays, menus choose.
- `barWidget.defaultSection`: `left`, `center`, `right`; lower `order` sits
  further toward the section's outer edge. Runtime preferences
  (`stillsuit-plugins place`) override both.
- `dependencies`: plugin ids whose services this plugin reads through
  `context.services.get`. Undeclared services return `null`.
- `capabilities`: free-form review labels; they do not sandbox.
- `keepLoaded`: keep the panel object alive after close. Default: unload.
- Entry-point paths are relative, inside the plugin directory, no symlinks.

## Construction

| Kind | Required properties |
|---|---|
| service | `context` |
| bar-widget | `context`, `outputId`, and `service` if the plugin declares one |
| panel / overlay / menu (per-output) | `context`, `screen`, `outputId`, and `service` if declared |
| panel / overlay / menu (global) | `context`, and `service` if declared |

The host injects `service` only for the plugin's own service. Other plugins'
services come from `context.services.get(id)`.

## `context`

```
theme        read-only theme.v2 view: semantic, component, typography, metrics, motion, effects
compositor   apiVersion, name, revision, outputs[], focusedOutputId, workspaces[], windows[],
             lastFocusedWindowId (last niri-focused window, kept while a layer surface holds focus; null once closed)
services     revision, has(id), get(id), state(id)   — declared dependencies only
panels       activeId, selectedId, selectedOutputId, focusedOutputId, isOpen(id), state(id)
logger       debug/info/warn/error(message)
settings     pluginId, values (from Nix + runtime preferences), paths {configRoot, dataRoot, stateRoot, packageRoot}
profiles     active, available[], revision, state (ready/switching/degraded/error), error
actions      surfaceOpen(id, payloadJson), surfaceClose(id), surfaceToggle(id, payloadJson),
             surfaceDismissPanels(), pluginUnload(id), pluginReload(id), pluginRescan(),
             profileActivate(id), windowFocus(windowId), workspaceFocus(workspaceId),
             shellPing(), shellStatus(), themeQuery(),
             agentPanel{Open,Hide,Toggle,Status,Terminate}(),
             appLaunch(desktopId, actionId), openUrl(url), openPath(path, "open"|"reveal"),
             copyText(text), sessionAction("lock"|"suspend"|"logout"|"reboot"|"poweroff")
```

The launch actions take names, never argv: `appLaunch` re-resolves the
desktop ID, and argv prefixes come from `programs.stillsuitShell.launch`.
They return `ok`, `unknown`, `invalid`, `unavailable`, or `error` (see the
host contract for which); treat anything but `ok` as a failure. `ok` means
submitted, not that the program started: the helper posts its own desktop
notification when a launch fails. `unavailable` means the helper has not yet
passed its startup check. Apps, URLs, and paths start in their own
`app.slice` scope through the `stillsuit-app-launch` helper. These actions are
context-only; IPC cannot reach them.

Payload JSON is surface data only; `{ "outputId": "..." }` places a panel.

## Hosted panel

```qml
Item {
    readonly property bool hostedPanel: true
    implicitWidth: context.theme.metrics.panelWidth
    implicitHeight: content.implicitHeight + context.theme.metrics.panelPadding * 2
    visible: false                       // the host sets visibility
    required property var context
    required property var screen
    required property string outputId
    function open(payloadJson) {}
    function close() {}
    Ui.ShellSurface { anchors.fill: parent; theme: context.theme; /* content */ }
}
```

The core places it below the bar on `outputId`, dismisses on outside press,
outside wheel, Escape, and on a banner for that output. Panels do not create
windows or handle dismissal.

## Hosted menu

```qml
FocusScope {
    readonly property bool hostedMenu: true
    implicitWidth: 640
    implicitHeight: content.implicitHeight
    visible: false                       // the host sets visibility
    required property var context
    function open(payloadJson) {}
    function close() {}
    // Optional: return true to take a toggle as a new open (for example a mode switch).
    function keepOpenOnToggle(payloadJson) { return false }
    Ui.ShellTextField { focus: true; theme: context.theme /* ... */ }
}
```

The core shows it on the output it opened on, over a dim scrim with
exclusive keyboard focus, centered at 22% of the output height. The host
focuses the root, so make it a `FocusScope` whose field sets `focus: true`.
Focus arrives when the host presents the menu, before its first paint, and
keys typed right after opening can arrive then. Keep the field ready from
`open()` on; never gate input or focus on the menu having painted.
Escape, a press outside the content, or a focused-output change closes it,
even while it is still loading. Opening a menu closes the open panel and the
reverse. Banners do not close menus.

A panel or menu may call `surfaceClose`/`surfaceOpen` on itself from `open()`,
`close()`, `keepOpenOnToggle()`, or a handler that runs while its host
presents it, such as `onParentChanged`; the router treats that as cancelling
the request in progress, not as an error. Never `destroy()` your own surface
root: the router then ends the route and unloads the contribution, and the
next open constructs it again.

## Lifecycle and containment

States: `unloaded → loading → loaded`, any → `error`, `loaded → unloaded` on
close without `keepLoaded`. A compile or construction error contains only that
plugin; the bar and other plugins continue. Containment raises a desktop toast
("<id> bar-widget omitted" with the error), logs a warning tagged with the
plugin id, and shows `"error"` in `stillsuit status`. Fixing the source
rediscovers it.

Runtime discovery snapshots each changed plugin tree into a content-addressed
generation, so a stable URL never serves stale QML. The first root claiming an
id wins, even if that copy is broken.

## Settings and state

`context.settings.values` merges Nix defaults, global preferences from
`~/.config/stillsuit/plugins.json`, and the active named profile. Writable
state belongs under `settings.paths.stateRoot` in a service-owned, versioned
file. Never derive paths from `HOME`.
