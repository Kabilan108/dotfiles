---
name: stillsuit-plugin
description: Build, change, or debug a Stillsuit shell plugin (bar widget, panel, service, overlay) on the live shell, or in the plugin workbench for isolated iteration. Use when asked to add a bar chip, make a panel, change how a widget looks, write a Stillsuit plugin, wire a service into the bar, or when a plugin disappears from or fails to load in the bar.
---

# Stillsuit plugin

A plugin is a directory with `manifest.json` plus QML entry points, loaded
in-process by the shell. Saving a file under `src/plugins/builtin/` is a live
deploy: the running shell picks it up within a second. A plugin that fails to
load is **contained** — removed from the bar and reported by a desktop toast,
the journal, and `status`; nothing crashes and nothing tells you unless you
look.

Repo: `~/dotfiles/packages/stillsuit-shell`. Paths below are relative to it.

## Loop (live shell)

1. **Locate.** Existing plugin: `src/plugins/builtin/<name>/`. New plugin:
   copy the closest example from `src/plugins/examples/` (see its README)
   into `src/plugins/builtin/<name>/` with a new manifest `id`
   (`stillsuit.<name>`), and add `(builtinPlugin "<name>")` to
   `home/desktop/wayland/quickshell/default.nix` so it survives a rebuild.
2. **Edit and save.** Then, before anything else:
   ```sh
   qs ipc -c stillsuit-next call stillsuit status | jq '.plugins["stillsuit.<name>"]'
   ```
   Loaded looks like `visual: {"bar-widget": "loaded"}` / `surface.state:
   "loaded"`. `"error"` anywhere, or an `errors` array, carries the QML or
   manifest message — fix that first. A plugin missing from the list failed
   manifest validation: `stillsuit-plugins validate` prints why.
3. **Look.** Screenshot the bar (`grim -o <output> /tmp/x.png`, read the
   image); open a panel with `qs ipc -c stillsuit-next call stillsuit-surface
   open stillsuit.<name> '{}'` and screenshot that too. Reach every state the
   plugin renders differently; if a state needs conditions you cannot produce
   on the live machine, use the workbench fixture for it (below).
4. **Cover.** Extend the plugin's fixture under `src/tests/` for the contract
   you changed; run it with `direnv exec "$PWD" bash <suite>` and capture the
   exit code. Fixtures prove the change stays; they never prove it works.
5. **Done** when status shows the plugin loaded with no error, every reachable
   state is verified in a screenshot, the fixture passes, and the plugin uses
   only the `context` facades and `Stillsuit.Ui`.

## Shared code needs a rebuild

Only `src/plugins/*` hot-loads. `src/ui/`, `src/services/`, `src/core/`,
`schemas/`, and `themes/` are served from the Nix store; edits there reach the
shell only after `rebuild`. A plugin that references a new shared property
before that rebuild is contained (unknown property → whole widget rejected).

When a change touches shared code:

1. Make the shared change and the plugin change together, coherently. Keep the
   old API untouched; add, do not repurpose.
2. Verify both in the workbench, which runs from `--source` and sees the
   checkout: `stillsuit-workbench`, then the loop above against it
   (`stillsuit-workbench status --json`, `open`, screenshot its output).
3. **Stop and report**: what changed, that a rebuild is required, and what you
   will verify after it. Do not rebuild. Do not add a hot-reload shim, alias,
   or fallback so the plugin limps along on the old host.
4. After the human rebuilds, run the live loop and only then say done.

## Workbench (isolated iteration)

`stillsuit-workbench` runs the same core on your other output with fixture
data, in a sandbox that never touches the live bar. Reach for it when: a new
plugin should not appear in the real bar yet; you need a state the machine
cannot produce (low battery, notification storm, failed transcription — see
`stillsuit-workbench fixtures`); or you are verifying a shared-code change.
Plugins go in `~/.config/stillsuit/workbench/plugins/<name>/`; a copy of a
builtin under the same id shadows it in the workbench only. Commands:
`status [--json]`, `fixture ID`, `open <name>`, `close`, `notify`, `stop`.
Details: `design-lab/README.md`.

## Contract in one screen

Details: `references/contract.md`. Source of truth: `docs/host-contract.md`.

- Entry points receive `required property var context` and, per kind,
  `service` (when the plugin declares one), `screen`, `outputId`.
- `context` has `theme`, `compositor`, `services.get(id)`, `panels`, `logger`,
  `settings`, `actions`. Nothing else reaches a plugin.
- A **service** is global and owns state, timers, processes. **Bar widgets and
  panels** are per-output views: no timers, sockets, or processes in them.
- A **panel** is `Item` content with `hostedPanel: true`, `implicitWidth`,
  `implicitHeight`, `open(payloadJson)`, `close()`. The core owns the window.
- Chips toggle their panel with
  `context.actions.surfaceToggle(id, JSON.stringify({outputId}))` and set
  `selected` from `context.panels.selectedId` and `selectedOutputId`.
- Import `Stillsuit.Ui as Ui`; use theme roles (`theme.semantic.*`,
  `theme.component.*`, `theme.metrics.*`), never literal colors or sizes.
  Component surface: `references/primitives.md`.

## Traps

- Manifest `id` must match `^stillsuit(\.[a-z][a-z0-9-]*)+$`; `entryPoints`
  keys are camelCase (`barWidget`) while `kinds` are kebab (`bar-widget`).
- A per-output panel that reads `context.compositor.focusedOutputId` lands on
  the wrong screen; use the `outputId` it was constructed with.
- `keepLoaded: true` keeps a panel's state across close; without it the panel
  is destroyed on close and rebuilt on open.
- `ShellBarCluster`: `secondaryIconName`/`secondaryIconSource` put a second
  icon beside the first; `badgeIconName` is a small corner overlay. Pick by
  intent, and never change what an existing property means.
