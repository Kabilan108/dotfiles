# Stillsuit Next Claude review recovery

Date: 2026-08-31

Primary Claude session: `d443951d-085e-47a9-9c14-29beaa773fd0`

Branch and reviewed range: `stillsuit-next`, `bb167a9..5f487bf3`

Activation status: none. This recovery did not switch a NixOS or Home Manager
generation, restart a production service, claim the notification bus, or touch a
live tmux session.

## Recovery status

The primary session launched four read-only reviewers. Three completed and
returned final reports. The Nix reviewer finished most of its inspection and
verification commands but hit the Claude rate limit before writing its verdict.

| Review | Agent ID | Status | Recovered result |
| --- | --- | --- | --- |
| Host core QML | `a21dbc6f7936eef29` | Complete | Two majors, five minors, one informational note |
| Nix module and packaging | `a43eb9e3a389b3291` | Interrupted | Command evidence recovered; no reviewer-authored final verdict |
| Services and plugins | `aeb8e40ca64ed9d7d` | Complete after one resume | One blocker, three majors, nine minors |
| Security-sensitive code | `af3029660854a4c5d` | Complete | Pass; no blockers or majors |

Tracer 0.2.2 did not have the active Claude session in its archive. A provider
sync remained in the scanning phase and produced no archive entry, so recovery
continued from Tracer's configured Claude provider source under
`~/.claude/projects/-home-kabilan-dotfiles/`. The primary record and all four
child records were present there. Reads did not alter or annotate the records.

## Verdict

Do not run Gate 2 yet.

Gate 1 is not blocked by these findings. It only applies the staged workspace
removal and Waybar ownership changes; it does not enable Stillsuit Next. It is
still reasonable to postpone Gate 1 until the repair set is reviewed, because
there is no technical need to change the live desktop while the cutover branch
is being corrected.

The agent-panel and notification command boundaries held. The security review
found no path from IPC or notification sender data to arbitrary command
execution, no unsafe tmux prefix matching, and no practical unrelated-PID kill
path.

## Required before Gate 2

### A1. Pass the output identity into real bar widgets

Severity from reviewer: blocker.

`packages/stillsuit-shell/src/plugins/builtin/bar/WidgetSlot.qml:69-72` creates
widgets with `context` and optional `service`, but no `outputId`.
`packages/stillsuit-shell/src/plugins/builtin/workspaces/WorkspaceWidget.qml:11`
therefore keeps its empty default and filters out every workspace. The D4
fixture masked this by setting `outputId` directly.

Fix: make `outputId` part of the bar-widget construction contract, declare it
on every built-in bar widget, and pass each `Bar.qml` window's value through
its `WidgetSlot`. Do not add an unknown initial property only to the current
components, because QML construction will reject widgets that do not declare
it. Add a production-path fixture that creates the real bar and proves
different outputs receive different workspace rows.

### A2. Invalidate an in-flight bar load before fallback activation

Severity from reviewer: major.

`packages/stillsuit-shell/src/core/PluginCatalog.qml:534-542` calls
`_activateFallback()` after a catalog document failure. The fallback path at
`:680-720` destroys the current bar but does not invalidate `barToken` or
decrement an in-flight visual load. A stale asynchronous completion can wedge
readiness at `not-ready` or replace the fallback with a second bar instance.

Fix: invalidate the bar load in `_documentFailed()` before fallback activation,
or refactor the bookkeeping so each load decrements `pendingVisualLoads`
exactly once. Do not blindly add `_invalidateBarLoad()` to every fallback path,
because component-error paths already call `_finishPendingVisualLoad()`. Cover
a catalog failure while the selected bar component is still loading.

### A3. Contain screen-reconciliation failures to one plugin

Severity from reviewer: major.

`packages/stillsuit-shell/src/core/SurfaceRouter.qml:610-616` returns from the
whole screen-reconciliation pass when one plugin fails. Later plugins retain
views for removed screens until another screen-change event.

Fix: continue with the next plugin after recording the failed contribution.
Add a two-plugin fixture in which the first fails and the second still migrates.

### A4. Accept the recorder's `meeting_queued` state

Severity from reviewer: major.

`bin/stillsuit-recorder:271-279` writes `phase: "meeting_queued"`, while
`packages/stillsuit-shell/src/services/RecordingService.qml:91-95` rejects that
phase as corrupt. Every successful `stop --meeting` therefore ends with a
corrupt UI state.

Fix: add `meeting_queued` to the version-1 state contract or normalize it to a
documented completed state. Test the helper output against the real service
parser.

### A5. Reload `/proc` before each resource sample

Severity from reviewer: major.

`packages/stillsuit-shell/src/plugins/builtin/resources/ResourceService.qml:40-43`
reuses `FileView.text()` without calling `reload()`. Quickshell's prepared file
view can return the cached first sample, freezing CPU and memory values.

Fix: reload both file views on each refresh, then parse their loaded contents.
The regression fixture must change the source data between two samples and
observe a changed result.

### A6. Derive recording elapsed time while the recorder is active

Severity from reviewer: major.

`packages/stillsuit-shell/src/services/RecordingService.qml:96-104` updates
`elapsedSeconds` only when the helper rewrites its state file. The recorder
does not write once per second, so the widget timer remains frozen between
state transitions.

Fix: use one global one-second timer while recording and derive elapsed time
from `started_at`, `paused_at`, and `paused_total`. Keep the recorder process
externally owned.

### A7. Repair the recorder-to-meeting executable closure

Recovered from the interrupted Nix review and independently confirmed.

`packages/stillsuit-shell/recorder-helper.nix:10,28-29` gives the wrapped
recorder only `gpu-screen-recorder` on `PATH`. The recorder invokes the mutable
absolute helper configured at
`home/desktop/wayland/quickshell/default.nix:17-19`. That helper has
`#!/usr/bin/env python3` and its enqueue path invokes `systemctl` at
`bin/meeting-minutes:325-338`. Neither executable is in the recorder wrapper's
restricted `PATH`, so `stop --meeting` cannot execute the enqueue flow from the
Nix-built helper even after A4 is fixed.

Fix: package or wrap the enqueue entry point with an exact closure containing
Python and systemd, then point `MEETING_HELPER` at that store-backed executable.
Test it under an empty ambient `PATH` with a fake user-systemd command.

## Nix cleanup before activation

### N1. Remove the unsupported `DataDirectory` service directive

`modules/home/stillsuit/service.nix:54-56` sets `RuntimeDirectory`,
`StateDirectory`, and `DataDirectory`. The installed systemd supports the first
two but has no `DataDirectory=` directive. It will ignore the unknown setting
and log a unit warning.

Fix: remove it or replace it with the intended supported directory directive.
Run `systemd-analyze --user verify` on the generated unit before Gate 2.

### N2. Do not claim malformed JSON is caught by `tryEval`

`modules/home/stillsuit/registry.nix:16-24` wraps `builtins.fromJSON` in
`builtins.tryEval`, and `assertions.nix:149-152` expects `parsed.success` to
produce a controlled assertion. On the installed Nix 2.34.8, malformed JSON
still aborts evaluation before that assertion.

This does not affect the current valid built-ins. Fix the diagnostic contract
or document that malformed manifest JSON is a hard evaluation error.

The interrupted reviewer did complete these clean checks before the rate
limit: all reviewed Nix files passed `nixfmt --check`; the canonical theme
validated against `theme.v1.json`; all three staged patches applied in gate
order; the post-patch Niri configuration validated; agent-panel defaults were
materialized only when absent; and the four IPC target names matched the gate
commands. The prior forced-enabled Jacurutu closure build also proves that the
Stillsuit Base16 projection and system Stylix integration evaluate together.

## Secondary fixes

These are not Gate 2 blockers, but they should be triaged before declaring the
shell finished.

- `NotificationModel.js:166-175` and `NotificationService.qml`: release live
  notification references when bounded history evicts their final row.
- `NotificationCard.qml:29,156`: sender-controlled notification bodies use
  `StyledText` after only an image-tag regex. Prefer `PlainText` or a complete
  allowlist sanitizer.
- `NotificationService.qml:246-256`: flush state synchronously after clear-all
  so a crash cannot resurrect cleared notifications.
- `NiriService.qml:91,321`: add bounded exponential reconnect backoff and a
  reconciliation timeout that clears the running generation.
- `RecordingService.qml:153-160`: watch or poll the parent directory so a state
  file created by an external keybinding is noticed.
- `BatteryService.qml:14`: remove the ambiguous `<= 1` scale heuristic, which
  maps a real integer 1 percent to 100 percent.
- `network/Widget.qml:12`: verify Quickshell 0.3's signal-strength units before
  multiplying by 100.
- `shell.qml:124-141`: align runtime theme checks with the schema's required
  `identity` and `palette` records.
- `ui/CursorSurface.qml:35`: use a defined theme role instead of the absent
  `colors.accent` path and hardcoded fallback.
- `schemas/manifest.v1.json` and `ManifestValidator.js:140-149`: add reverse
  schema constraints so undeclared-kind entry points cannot pass schema
  validation only to fail at runtime.
- `PluginCatalog.qml:534-542`: preserve per-plugin failure records when adding
  a catalog document failure.
- `SurfaceRouter.qml:590-601`: decide whether a global open surface should be
  rehomed when its output disappears instead of retaining a dead placement.
- A pre-versioned meeting status file is reported unsupported until the next
  meeting run rewrites it. Handle or document the one-time migration.
- `CompositorAdapter.qml:30` serializes the full compositor state twice per
  event. Keep it unless profiling shows event-load trouble.

The security reviewer reported two low-value notes only: the unavoidable
check-then-kill PID recycle window in the agent panel, and the need to keep the
existing `niri validate` guard for the staged proportional window height.

## Repair and review order

1. Fix A1 through A7 without activating the module.
2. Add focused regression fixtures for each defect. Do not rely on the old D4
   fixture's manual `outputId` injection.
3. Fix N1 and either fix or document N2.
4. Run the full isolated fixture ladder, ShellCheck, Ruff, schema validation,
   `nixfmt --check`, `nix flake check --no-build`, the shell package build, and
   the forced-enabled Jacurutu no-link closure build.
5. Reapply Gate 1 then Gate 2 patches only in a disposable archived tree. Run
   `niri validate`, Nix formatting, flake evaluation, and generated-unit
   verification there.
6. After the desktop session is unlocked, rerun the isolated shadow preview.
   Capture the real bar on both outputs plus audio and resources. Confirm that
   resources change over time and the workspaces widget is populated.
7. Review the resulting diff and evidence ledger. Gate 1 may then be approved
   independently. Gate 2 still requires explicit human approval and the
   prepared bounded cutover procedure.
