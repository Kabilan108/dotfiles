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
compositor   apiVersion, name, revision, outputs[], focusedOutputId, workspaces[], windows[]
services     revision, has(id), get(id), state(id)   — declared dependencies only
panels       activeId, selectedId, selectedOutputId, focusedOutputId, isOpen(id), state(id)
logger       debug/info/warn/error(message)
settings     pluginId, values (from Nix + runtime preferences), paths {configRoot, dataRoot, stateRoot, packageRoot}
actions      surfaceOpen(id, payloadJson), surfaceClose(id), surfaceToggle(id, payloadJson),
             surfaceDismissPanels(), pluginUnload(id), pluginReload(id), pluginRescan(),
             shellPing(), shellStatus(), themeQuery(), agentPanel{Open,Hide,Toggle,Status,Terminate}()
```

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

## Lifecycle and containment

States: `unloaded → loading → loaded`, any → `error`, `loaded → unloaded` on
close without `keepLoaded`. A compile or construction error contains only that
plugin; the bar and other plugins continue. Fixing the source rediscovers it.

Runtime discovery snapshots each changed plugin tree into a content-addressed
generation, so a stable URL never serves stale QML. The first root claiming an
id wins, even if that copy is broken.

## Settings and state

`context.settings.values` merges Nix defaults with `~/.config/stillsuit/plugins.json`
runtime preferences. Writable state belongs under `settings.paths.stateRoot`
in a service-owned, versioned file. Never derive paths from `HOME`.
