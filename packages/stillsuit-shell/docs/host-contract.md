# Stillsuit host contract v1

This contract is the boundary between the Stillsuit host and trusted,
dotfiles-owned plugins. The host runs reviewed QML in-process. Manifest and
path validation contain mistakes; they are not a security sandbox.

The production config identity is canonical and stable. The host generates a
new `instanceId` for each process only for logs and diagnostics. Callers must
not select "the newest" instance as a correctness mechanism.

## Manifest and construction

The host accepts only manifests that validate against
`schemas/manifest.v1.json`. It also checks that every entry point resolves
below the plugin's Nix store root, exists, and matches a declared kind. The host
rejects unknown kinds, unsupported `apiVersion` values, duplicate IDs, missing
dependencies, dependency cycles, and duplicate IPC targets.

Each manifest declares construction scope per kind:

- `service` is always `global`.
- `bar` and `barWidget` are always `per-output`.
- `panel`, `overlay`, and `menu` declare `global` or `per-output`.

The host constructs every global service once and injects that instance into
consumers. A `Variants` owner may create per-output views, but it must not
create another service, timer, socket, watcher, recorder, or IPC handler for
each output.

Dynamic construction must handle `QQmlComponent.Loading`. The registry keeps
the `QQmlComponent` alive for as long as a registered widget can create visual
instances. A component is not registered until it reaches `Ready`.

Every `barWidget` entry point declares `required property string outputId` in
addition to its required `context` property and any required service. The bar
passes the owning window's output identity to `WidgetSlot`, and `WidgetSlot`
includes it in the initial-property map passed to `createObject`. Widgets must
not infer their output later from global focus state.

## Injected `HostContext`

Every entry point may declare `required property var context`. The host injects
one object with exactly these top-level properties:

```qml
QtObject {
  readonly property var theme
  readonly property QtObject compositor
  readonly property QtObject services
  readonly property QtObject panels
  readonly property QtObject logger
  readonly property QtObject settings
  readonly property QtObject actions
  readonly property string instanceId
}
```

Plugins do not receive the composition root, registries, loaders, raw process
objects, or an unrestricted command runner.

### `theme`

`theme` is the read-only effective `theme.v1.json` record. Its public grouped
roles are `colors`, `controls`, `typography`, `geometry`, and `motion`. Flat
legacy aliases may exist during the port, but they are not part of this
contract. Theme selection is rebuild-time in v1.

### `compositor`

`compositor` is a read-only Niri adapter with this shape:

```text
apiVersion: "1"
name: "niri"
revision: integer
outputs: OutputSnapshot[]
focusedOutputId: string
workspaces: WorkspaceSnapshot[]
windows: WindowSnapshot[]
```

Snapshots contain plain data and no process handles. Plugin-specific view code
may filter or bind these records. Compositor mutations, when added, go through
named methods on `actions`; plugins cannot send raw `niri msg` arguments.

### `services`

`services` is a read-only registry facade:

```text
revision: integer
has(id: string): bool
get(id: string): QtObject | null
state(id: string): "unloaded" | "loading" | "loaded" | "error"
```

`get` returns only a declared dependency. It never creates a second service.
Each service publishes its own versioned, narrow contract.

### `panels`

`panels` is a read-only view of routing state:

```text
activeId: string
focusedOutputId: string
isOpen(id: string): bool
state(id: string): "unloaded" | "loading" | "loaded" | "error"
```

The facade does not mutate surfaces. Plugins use the typed `actions` methods.

### `logger`

The host binds every log record to the plugin ID and `instanceId`:

```text
debug(message: string): void
info(message: string): void
warn(message: string): void
error(message: string): void
```

Messages are text, not format strings or shell fragments.

### `settings`

`settings` is a read-only effective view:

```text
pluginId: string
values: object
paths: {
  configRoot: absolute string,
  dataRoot: absolute string,
  stateRoot: absolute string,
  packageRoot: absolute string
}
```

The host resolves the first three roots once from the isolated or real XDG
environment. `packageRoot` is the plugin's store path. Plugins must not rebuild
paths from `HOME`, mix XDG and project conventions, or write Home Manager-owned
defaults. Writable state uses a service-owned, versioned file below the
injected root.

The agent panel's model, reasoning effort, and service tier are the one v1
runtime configuration exception. Its helper reads
`configRoot/agent-panel.json`; IPC still cannot change those values or its
command.

### `actions`

`actions` exposes the same literal operations as the IPC facade:

```text
surfaceOpen(id: string, payloadJson: string): string
surfaceClose(id: string): string
surfaceToggle(id: string, payloadJson: string): string
pluginUnload(id: string): string
pluginReload(id: string): string
pluginRescan(): string
shellPing(): string
shellStatus(): string
themeQuery(): string
agentPanelOpen(): string
agentPanelHide(): string
agentPanelToggle(): string
agentPanelStatus(): string
agentPanelTerminate(): string
```

An ID must name a validated catalog entry. Payload JSON is surface data only;
the host and helpers never turn it into argv, QML source, a file path, or a
shell command.

## Surface lifecycle

Every surface has one of four states:

```text
unloaded -> loading -> loaded
    ^          |          |
    |          v          v
    +-------- error <-----+
```

Valid transitions are:

- `unloaded -> loading` when an enabled surface is opened or preloaded.
- `loading -> loaded` when its component and object are ready.
- `loading -> error` for compilation or construction failure.
- `loaded -> error` for a fatal host-observed plugin failure.
- `loaded -> unloaded` on close when `keepLoaded` is false.
- `error -> loading` only after an explicit reload or a catalog rescan that
  changed the entry.
- Any state may become `unloaded` on disable or unload.

Open payloads are FIFO while a surface is `loading`. The router clears every
queued payload for that surface on hide, disable, error, unload, or reload.
After `loaded`, it delivers the queue once and clears it. A later component
completion must never replay a payload cleared by a summon-hide race.

For a global surface, the router selects the focused output when open begins
and keeps that placement for the open session. For a per-output surface, the
host owns the `Variants` instances. The plugin still has one logical route and
does not create IPC handlers per output.

## IPC v1

The Quickshell IPC facade has no generic `call`, command-string, config-write,
or whole-shell kill endpoint.

| Target | Method | Arguments | Result |
|---|---|---|---|
| `stillsuit` | `ping` | none | literal `ok` when the registry is ready |
| `stillsuit` | `status` | none | JSON with config ID, `instanceId`, readiness, catalog revision, and plugin states |
| `stillsuit` | `theme` | none | effective theme JSON |
| `stillsuit-surface` | `open` | plugin ID, payload JSON | `ok`, `unknown`, `disabled`, or `error` |
| `stillsuit-surface` | `close` | plugin ID | `ok`, `unknown`, or `error` |
| `stillsuit-surface` | `toggle` | plugin ID, payload JSON | `ok`, `unknown`, `disabled`, or `error` |
| `stillsuit-plugin` | `unload` | plugin ID | `ok`, `unknown`, or `error` |
| `stillsuit-plugin` | `reload` | plugin ID | `ok`, `unknown`, or `error` |
| `stillsuit-plugin` | `rescan` | none | `ok` |
| `stillsuit-agent-panel` | `open` | none | helper status |
| `stillsuit-agent-panel` | `hide` | none | helper status |
| `stillsuit-agent-panel` | `toggle` | none | helper status |
| `stillsuit-agent-panel` | `status` | none | structured helper status JSON |
| `stillsuit-agent-panel` | `terminate` | none | helper status |

The agent-panel methods pass one literal action to the fixed helper. They do
not accept a model, reasoning effort, service tier, working directory, prompt,
or extra argument.

## Failure containment and fallback

- A malformed manifest, unknown kind, unsupported host API, unsafe path,
  missing dependency, or component error omits only that plugin and records an
  actionable error in `status`.
- A selected bar plugin that fails validation, compilation, or construction
  releases its load claim and activates the built-in Stillsuit bar. Exactly one
  bar owns an exclusion zone at a time.
- A bar widget that fails releases its component and slot claim. Other widgets
  and the bar continue. A later explicit reload may retry it.
- A failed optional service is `error`; dependants that declared it do not
  load. Unrelated services and surfaces continue.
- A surface failure closes its route, clears payloads, and enters `error`.
- The built-in fallback bar is part of the host package, not a replaceable
  catalog entry. If it cannot load, readiness fails and systemd applies its
  normal process restart policy.

## Process replacement

Quickshell 0.3.0 returns from `quickshell kill` before the selected process has
exited. No Stillsuit code may assume synchronous kill or use a fixed sleep as a
barrier.

Production process replacement belongs to the systemd user unit. Its ordered
stop and start must finish the old process before launching the replacement.
Any standalone recovery helper must instead:

1. Resolve the exact old PID.
2. Request termination.
3. Wait with a bounded timeout for that PID to disappear.
4. If notifications are in scope, wait for
   `org.freedesktop.Notifications` to have no owner.
5. Start the canonical config.
6. Wait for the new PID, then call `stillsuit ping` until the registry reports
   ready or a bounded timeout expires.

A live PID is not readiness proof. Plugins may unload, reload, or rescan their
objects. They never receive a whole-shell kill or restart action.

## Recorder state v1

The external recorder owns
`settings.values.recordingStatePath`. The one global `RecordingService` reads
that file and never starts, stops, pauses, resumes, or signals the recorder
except in direct response to a typed user action. Per-output views only consume
the service snapshot.

Version 1 accepts `idle`, `recording`, `paused`, `stopping`, `completed`,
`meeting_queued`, and `error` phases. `meeting_queued` is a successful completed
state with the additional `meeting_job_id` field. While a recording is active,
the service derives elapsed seconds once per second from `started_at`,
`paused_at`, and `paused_total`. A current pause ends the elapsed interval at
`paused_at`; completed pause time is subtracted through `paused_total`. The
helper's `elapsed_seconds` remains the fallback for older or incomplete
version-1 active records without `started_at`.

## Shadow-mode boundary

Tests use a separate Quickshell config ID and temporary `HOME`,
`XDG_CONFIG_HOME`, `XDG_DATA_HOME`, and `XDG_STATE_HOME`. Shadow manifests omit
or fixture the production bar, notification daemon, recorder, meeting worker,
lock, and polkit contributions. Notification tests always run under
`dbus-run-session`.
