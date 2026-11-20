# Niri state comes from the event stream, with reconciliation as backstop

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

niri's event stream resends full workspace and window snapshots on connect, but it does not carry outputs. niri-ipc's own reducer asserts that referenced workspaces and windows exist, and a focused window that opens or changes takes focus without a separate `WindowFocusChanged`. The niri CLI addresses a workspace only by index on the focused monitor. Keyed views such as `ScriptModel` rebuild a row whenever its object identity changes.

## Decision

- The event stream is authoritative. Reconciliation (`niri msg` for outputs, workspaces and windows) runs on stream start, on screen changes and after an event the parser cannot apply. The 60 s interval (`reconciliationIntervalMs`, 5 s timeout) is a safety net. A request during a running generation is deferred until it finishes.
- `_eventChanges` returns null for an unknown event, a payload that fails the schemas, or a reference to a missing workspace or window, and the caller reconciles instead. The schemas mirror niri-ipc's `Workspace`, `Window` and `WindowLayout` structs; `Option<T>` fields may be null or absent.
- Collections the stream touches while a reconciliation is in flight (`_streamTouched`) keep the stream's value, since the reconciliation snapshot may predate the event.
- `_upsertWindow` mirrors the niri-ipc reducer: a focused upserted window clears focus on every other window.
- Rows are never mutated. `_patchRows` and `CompositorAdapter._mergeRows` copy only changed rows, and unchanged rows keep their identity.
- `focusWindow` and `focusWorkspace` use fixed argv apart from a validated integer. `focusWorkspace` resolves the snapshot id to an output and index, focusing that output first. A request that arrives while a command runs replaces any earlier pending one: the last click wins.

## Consequences

The adapter's row identity is part of its contract with plugins. Event types niri adds later fall back to reconciliation until the parser learns them.

## Where

- `packages/stillsuit-shell/src/services/NiriService.qml` (`reconciliationIntervalMs`, `_streamTouched`, `_eventChanges`, `_workspaceSchema`, `_patchRows`, `_upsertWindow`, `focusWindow`, `focusWorkspace`)
- `packages/stillsuit-shell/src/services/CompositorAdapter.qml` (`update`, `_mergeRows`)
