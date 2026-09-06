---
name: stillsuit-plugin
description: Build, change, or debug a Stillsuit shell plugin (bar widget, panel, service, overlay) against the plugin workbench. Use when asked to add a bar chip, make a panel, write a Stillsuit plugin, wire a service into the bar, or when a plugin fails to load in the shell.
---

# Stillsuit plugin

A plugin is a directory with `manifest.json` plus QML entry points. The host
loads it in-process; the workbench runs that same host on a spare output with
fixture data, and reloads a plugin within a second of each save. Work there,
never against the live shell.

Repo: `~/dotfiles/packages/stillsuit-shell`. Paths below are relative to it.

## Loop

1. **Start the workbench** (once; it stays up):
   ```sh
   stillsuit-workbench            # picks the output you are not focused on
   stillsuit-workbench status     # ready, output, fixture, plugin errors
   ```
2. **Copy the closest example** from `src/plugins/examples/` into
   `~/.config/stillsuit/workbench/plugins/<name>/` and set a new manifest `id`
   (`stillsuit.<name>`). Read `src/plugins/examples/README.md` to pick.
3. **Edit and save.** After each save, before anything else:
   ```sh
   stillsuit-workbench status --json | jq '.plugins["stillsuit.<name>"]'
   ```
   `state: "error"` carries the QML or manifest error text. A plugin absent
   from the list did not pass manifest validation: `stillsuit-workbench plugins`
   prints the validator's reason.
4. **Look at it.** `stillsuit-workbench open <name>` for a panel, then
   screenshot the workbench output (`grim -o <output>`, read the image). Switch
   scenarios with `stillsuit-workbench fixture <id>` (`fixtures` lists them)
   and screenshot each state the plugin renders differently.
5. **Done** when: status shows no error, every state you can reach through
   fixtures renders correctly in a screenshot, and the plugin uses only the
   `context` facades and `Stillsuit.Ui` components.
6. **Promote**: move the directory into `src/plugins/builtin/<name>/`, keep
   the id, then register it in `home/desktop/wayland/quickshell/default.nix`
   (`builtinPlugin "<name>"`). That needs a rebuild; say so rather than doing it.

## Contract in one screen

Details: `references/contract.md`. Full source of truth: `docs/host-contract.md`.

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
- A per-output panel that reads `context.compositor.focusedOutputId` will land
  on the wrong screen; use the `outputId` it was constructed with.
- `keepLoaded: true` keeps a panel's state across close; without it the panel
  is destroyed on close and rebuilt on open.
- The workbench bar sits below the production bar; that offset is workbench
  only, panels position themselves from the theme and need no adjustment.
- `stillsuit-workbench call TARGET FN ...` is the raw IPC escape hatch; the
  named commands cover everything a plugin needs.
