# Stillsuit works around Quickshell 0.3 binding behaviours and pins them with fixtures

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Several Quickshell 0.3 bindings, and the tools behind them, behave in ways the services and plugins must compensate for:

- `Process`: a program that cannot start changes `running` without emitting `exited`.
- `wl-copy` reads stdin until end of input.
- UPower: Quickshell 0.3 converts the 0 to 100 D-Bus percentage to 0.0 to 1.0, so a wire-level 1 percent arrives as 0.01. `UPowerDevice` does not expose design capacity, cycle count or charge thresholds.
- PipeWire: node properties such as `api.bluez5.address` are populated only on bound nodes.
- `Socket`: a failed socket keeps its internal `QLocalSocket`, and setting `connected = true` again does not start a new attempt.
- MPRIS: players signal position only on seeks.
- `PowerProfiles` reports Balanced even when power-profiles-daemon is absent. Setting a profile writes it optimistically and only logs a rejected D-Bus `Set`.
- `FileView` with `watchChanges` watches the target's parent directory, including while the target does not exist.
- Quickshell 0.3.1's `ScriptModel` with object rows (`objectProp`) rewrites positions after a changed or removed row without checking keys, so it rebinds delegates by position and hands a removed row's delegate to its neighbour.
- List-valued plugin settings reach QML as `QVariantList`, which fails `Array.isArray`.

## Decision

- `AppLaunch` treats `running` turning false as the end of a helper check, and closes `wl-copy`'s stdin after writing.
- `BatteryService` treats the device percentage as 0.0 to 1.0 and scales it back to percent, and reads the missing details when the battery appears or changes state, debounced by 2000 ms.
- `BluetoothService` binds sink nodes with a `PwObjectTracker` only while a connect selects its audio output.
- `DictatorService` recreates its socket through a `Loader` on each retry, with backoff capped at 8000 ms.
- `MediaService` runs a 500 ms position ticker only while a view holds a tracking ref.
- `PowerService` probes `powerprofilesctl list` once to decide availability, then follows `PowerProfiles` property changes, and re-reads 750 ms after a write.
- `RecordingService` relies on `FileView`'s parent-directory watch to notice when the recorder first creates its state file.
- The launcher result list and the workspace widget give `ScriptModel` plain string keys, and each delegate reads its row from a key map. A narrowed or reordered result set then moves, inserts and removes delegates correctly, and a compositor event keeps each workspace's cell instead of recreating every cell. The bar hands its `ScriptModel` one record object per plugin so slots reconcile by record identity.
- Plugins read list settings by checking for an object with a numeric `length` and copying it with `Array.prototype.slice.call` (or an index loop) instead of using `Array.isArray`.
- Fixtures pin these: the d3 fixture feeds a battery percentage of 0.01 and expects 1; the d5 fixture deletes the recorder state file, restarts, recreates it externally, and expects a load without an IPC refresh; the d2 fixture removes a middle workspace in the same update that changes the row before it and checks each surviving cell keeps its workspace; the bar-v2 fixture removes a middle marker and checks later slots keep their widget.

## Consequences

Each workaround should be rechecked on a Quickshell upgrade, with these fixtures re-run, and dropped when the binding changes. The 2000 ms and 750 ms delays are latency the user can see. Until `ScriptModel` diffs object rows by key, any new list of objects keyed by identity should use the string-key pattern; if upstream fixes it, the workaround can be reconsidered but the regression checks should stay. Any new list setting must use the array-like check, or it silently falls back to its default.

## Where

- `packages/stillsuit-shell/src/services/AppLaunch.qml` (`helperCheck`, `copyProcess`)
- `packages/stillsuit-shell/src/services/BatteryService.qml` (`percentage`, `detailRefreshDelay`)
- `packages/stillsuit-shell/src/services/BluetoothService.qml` (`audioCandidateNodes`, `pipewireTracker`)
- `packages/stillsuit-shell/src/services/DictatorService.qml` (`reconnectTimer`)
- `packages/stillsuit-shell/src/services/MediaService.qml` (`positionTimer`)
- `packages/stillsuit-shell/src/services/PowerService.qml` (`probeArgv`, `confirmTimer`)
- `packages/stillsuit-shell/src/services/RecordingService.qml` (`stateFile`)
- `packages/stillsuit-shell/src/plugins/builtin/launcher/Menu.qml` (result list model)
- `packages/stillsuit-shell/src/plugins/builtin/workspaces/WorkspaceWidget.qml` (`workspaceKeys` Repeater)
- `packages/stillsuit-shell/src/plugins/builtin/bar/Bar.qml` (`registrationsFor`)
- `packages/stillsuit-shell/src/plugins/builtin/clipboard/ClipboardModel.js` (`_list`)
- `packages/stillsuit-shell/src/plugins/builtin/dev-checkouts/Service.qml` (`primaryLinks`)
- `packages/stillsuit-shell/src/plugins/builtin/agent-usage/Service.qml` (`configuredAccounts`)
- `packages/stillsuit-shell/src/tests/d3-services/Fixture.qml`
- `packages/stillsuit-shell/src/tests/d5-workflows/run.sh`
- `packages/stillsuit-shell/src/tests/d2-compositor/run-fixtures.sh`
- `packages/stillsuit-shell/src/tests/bar-v2/fixture-shell.qml` (`removeMiddleMarker`)
