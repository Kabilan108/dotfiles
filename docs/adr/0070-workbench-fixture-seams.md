# Workbench fixtures adapt to the real session through narrow seams

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The workbench runs the production core against fixture data, either on one output of the live session or on a headless compositor. Fixtures are written by hand and name their output `WB-1`. Battery fixtures use human percentages, while `BatteryService` expects UPower's 0 to 1 scale as Quickshell 0.3 reports it. A headless shadow fixture has no `PanelWindow` backend. The packaged `stillsuit-plugins` carries its Python dependencies (jsonschema); the raw script in a `--source` checkout does not.

## Decision

- `SyntheticCompositor` builds outputs from the real Quickshell screens it was given and retargets `WB-1` to the first one. A fixture's `focusedOutputId` only selects among those screens.
- `SyntheticCompositor.focusWorkspace` updates the snapshot the way niri's `WorkspaceActivated` event would. `lastFocusedWindowId` is null unless the named window exists, as in the niri adapter.
- `FixtureModels` divides battery percentages above 1 by 100.
- `shell.qml` gives the built-in fallback bar a `QtObject` stub with `emergencyFallback: true` for the headless fixture. Production never receives it: failing to construct the packaged bar keeps readiness false.
- `stillsuit-workbench` prefers `stillsuit-plugins` from `PATH` and falls back to the source script.

## Consequences

Fixtures stay portable across machines with different output names. A fixture that names a second output gets no special handling beyond `WB-1`. The source-script fallback fails on manifest validation when jsonschema is missing.

## Where

- `packages/stillsuit-shell/src/workbench/SyntheticCompositor.qml` (`apply`, `_retarget`, `focusWorkspace`, `lastFocusedWindowId`)
- `packages/stillsuit-shell/src/workbench/FixtureModels.qml` (battery model)
- `packages/stillsuit-shell/src/shell.qml` (`builtinFallbackBar`)
- `packages/stillsuit-shell/bin/stillsuit-workbench` (`plugin_helper`)
