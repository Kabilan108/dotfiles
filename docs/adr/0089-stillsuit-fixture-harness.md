# Stillsuit runtime fixtures isolate from the live session and wait out Qt asynchrony

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Runtime fixtures load services and plugins from the live checkout inside a real Quickshell process. Several environment and Qt behaviours make naive fixtures flaky or unsafe:

- Quickshell hot-reloads on file changes, so an unrelated edit in the checkout would reset the state under test.
- A fixture that maps windows on the default platform would attach overlays to the live compositor.
- `qs ipc` occasionally answers "Not ready to accept queries yet." without running the call.
- Completion order between a QML root and its children is not defined.
- Widget components load asynchronously, and pure additions reach the bar on a later event-loop turn.
- Rebuilds scheduled with `Qt.callLater` can land after a check that already passed.
- Real key delivery spins the event loop, so a step timer can fire while a step is still acting.
- A headless output's name varies by backend.

## Decision

- Fixtures set `settings.watchFiles: false` and run service-only lanes with `QT_QPA_PLATFORM=offscreen`. Compositor lanes use a private headless sway with `WAYLAND_DISPLAY` and `XDG_RUNTIME_DIR` pointing at it, never the host session.
- IPC helpers retry the exact "Not ready" reply, which never means the call took effect.
- Startup checks run from `Component.onCompleted` through `Qt.callLater`.
- Asynchronous checks are polled and answer "pending" until ready; negative checks re-check after a settle delay.
- The launcher QML fixture guards its step tick against re-entry.
- Argv assertions skip the monitor name the headless backend chooses.

## Consequences

New fixtures should follow the same pattern. If Quickshell fixes the "Not ready" reply, the retry loops can go.

## Where

- `packages/stillsuit-shell/src/tests/d2-compositor/fixture-shell.qml` (`settings.watchFiles`)
- `packages/stillsuit-shell/src/tests/d2-compositor/run-fixtures.sh` (`ipc`)
- `packages/stillsuit-shell/src/tests/d5-workflows/run.sh` (`QT_QPA_PLATFORM`)
- `packages/stillsuit-shell/src/tests/clipboard/e2e-headless.sh`
- `packages/stillsuit-shell/src/tests/app-launch/fixture-shell.qml` (`Component.onCompleted`)
- `packages/stillsuit-shell/src/tests/fixtures/HostCoreRepairFixture.qml` (`runWidgetStability`)
- `packages/stillsuit-shell/src/tests/bar-v2/run.sh` (`wait_for_constructions`)
- `packages/stillsuit-shell/src/tests/launcher-qml/fixture-shell.qml` (`ticking`, `tick`)
- `packages/stillsuit-shell/src/tests/recording-meetings/run.sh` (`lastStartArgs` checks)
