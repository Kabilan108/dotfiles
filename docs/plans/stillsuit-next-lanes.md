# Stillsuit Next lane ownership

All lane branches start from the Phase 0 contract commit on `stillsuit-next`.
Workers use isolated worktrees below `/tmp/stillsuit-lanes/`, touch only their
assigned paths, commit their lane, and finish with a changed-file summary. The
orchestrator owns the main checkout, all shared-file edits, diff review,
merges, and the evidence ledger.

No lane may activate or rebuild a generation, restart or enable a service,
kill a live process, modify the upstream checkout, touch the live session
notification bus, or push a branch. Verification commands must preserve and
report their exit codes.

## Dependency order

```text
Phase 0 -> A, B, C, E, F
                |
                +-> D1, D2, D3, D4, D5 after B compiles
                                      |
                                      +-> integration
```

Lane F must merge before D1 so the port does not reintroduce agent-workspace
styling. Lane A and Lane C remain path-disjoint. Lane C reports its exact
package/module wiring request; the orchestrator applies it after reviewing
both lanes.

## Orchestrator-only paths

- `packages/stillsuit-shell/schemas/**`
- `packages/stillsuit-shell/docs/host-contract.md`
- `docs/plans/stillsuit-next-lanes.md`
- `docs/plans/stillsuit-next-evidence.md`
- shared integration edits, including Lane C wiring into Lane A files
- merge conflict resolution

## Lane A: Nix package, module, and theme

Effort: medium.

Exclusive paths:

- `modules/home/stillsuit/**`
- `packages/stillsuit-shell/default.nix`
- `packages/stillsuit-shell/themes/**`
- `docs/attribution/omarchy-quattro.md`

Build:

- Typed `programs.stillsuitShell` options, assertions, theme generation,
  deterministic store-backed registry, default-off systemd user unit, and
  exact runtime inputs.
- Assert exactly one bar owner and one notification owner. Validate plugin IDs,
  paths, manifests, and host API compatibility.
- Generate the Stillsuit theme JSON and lossy base16 projection from one
  canonical Catppuccin Mocha record. Never reconstruct the canonical record
  from base16.
- Support `development.sourceMode = "store" | "local"`. Production uses store
  source. Do not add a legacy backend or provider switches.
- Leave a documented integration point for the agent-panel helper without
  adding a stub command or touching Lane C paths.

Acceptance:

- `nixfmt --check` passes on owned Nix files.
- `nix flake check --no-build` passes.
- The Jacurutu Home Manager closure evaluates.
- `nix build --no-link` builds the shell package.
- No activation occurs.

## Lane B: host core and interaction primitives

Effort: high.

Exclusive paths:

- `packages/stillsuit-shell/src/shell.qml`
- `packages/stillsuit-shell/src/core/**`
- `packages/stillsuit-shell/src/ui/**`
- `packages/stillsuit-shell/src/tests/**`, except notification fixtures owned
  by Lane E

Build:

- Small composition root, `HostContext`, validated plugin catalog,
  single-instance service registry, lazy surface router, and typed IPC facade.
- Preserve `QQmlComponent` ownership for registered widgets and support the
  initiating call returning while a component is `Loading`.
- Port the upstream panel, keyboard, pointer, and cursor interaction contracts
  with Stillsuit styling, file-level MIT attribution, and no Hyprland policy.
- Contain malformed manifests, broken components, and unknown kinds to one
  plugin. Provide built-in bar fallback and widget-claim release.
- Implement the process and readiness rules in `host-contract.md`. Do not add a
  synchronous-kill assumption or a whole-shell kill action.

Acceptance:

- Isolated host boot uses a separate config ID and temporary XDG roots.
- Valid, malformed, broken-QML, and unknown-kind fixtures reach the expected
  catalog states.
- Broken-bar fallback works.
- Repeated plugin reload leaves one process and one IPC owner.

## Lane C: agent quake panel

Effort: medium.

Exclusive paths:

- `packages/stillsuit-shell/src/plugins/builtin/agent-panel/**`
- `packages/stillsuit-shell/bin/stillsuit-agent-panel`
- `docs/plans/staged-niri-changes.md`, agent-panel section only

Build:

- One serialized helper with literal `open`, `hide`, `toggle`, `status`, and
  `terminate` actions.
- One named `stillsuit-agent` tmux session runs a fixed Codex command. Model,
  reasoning effort, and service tier come from
  `~/.config/stillsuit/agent-panel.json`, with defaults described for Lane A.
- Ghostty uses app ID `io.stillsuit.AgentPanel`. Hiding closes only the Ghostty
  window; tmux persists.
- Plugin manifest, service, and bar widget use HostContext v1.
- Report exact helper runtime inputs, default-config materialization, and Nix
  package wiring needed from Lane A. Do not edit Lane A files.

Acceptance:

- A scripted toggle storm leaves one tmux session and at most one matching
  Ghostty window.
- Hostile IPC payloads cannot change argv.
- Tests cover absent tmux session, stale window, and dead Codex states.

## Lane E: notification engine

Effort: high.

Exclusive paths:

- `packages/stillsuit-shell/src/services/Notification*`
- `packages/stillsuit-shell/src/plugins/builtin/notifications/**`
- notification-only fixtures below `packages/stillsuit-shell/src/tests/**`

Build:

- Split D-Bus/live-reference/timer/action work, plain snapshots and bounded
  history, DND/retention/output policy, and center/toast views.
- Preserve named and default freedesktop actions, direct invocation, DND
  classes, center behavior, and millisecond timeout semantics.
- Add replacement snapshots, deadline restart, archive-then-expire behavior,
  corrupt-record isolation, and a single multi-output presentation policy.
- Treat every executable hint, including `omarchy-exec`, as inert data.
- Shadow mode must not claim the live notification name.

Acceptance:

- Every notification test runs inside `dbus-run-session`.
- Requested timeouts, replacements, actions, DND classes, a 100-notification
  burst, malformed history, and forged executable hints pass before and after
  restart.

## Lane F: agent-workspace removal

Effort: medium.

Exclusive paths and hunks:

- delete `bin/agent-workspace-pin`
- agent-workspace package/service hunks in
  `home/desktop/wayland/niri/default.nix`
- agent-workspace styling in
  `home/desktop/wayland/quickshell/stillsuit/TopBar.qml`
- `agents/skills/niri-computer-use/**`
- `docs/plans/staged-niri-changes.md`, workspace-removal section only, or a
  separate staged patch below `docs/plans/`

The lane must not edit
`home/desktop/wayland/compositors/niri/config.kdl`. It records the exact
workspace, `acu.*`, and Mod+0 removal as staged material, applies that material
to a temporary config, and validates the temporary file.

Build:

- Remove the pin script, package/service, TopBar styling, `acu --bg` behavior,
  doctor check, and recipes as one coherent feature deletion.
- Preserve ordinary and waited computer-use launches.

Acceptance:

- A scoped repository search finds no remaining agent-workspace, pin, or
  `acu --bg` contract references outside historical plans/evidence and the
  staged removal description.
- `niri validate` passes against the temporary staged config.

## Lane D: desktop port

Lanes D1 through D5 start only after Lane B compiles. Each uses medium effort.
They own only new files below `packages/stillsuit-shell/src/services/**` and
`packages/stillsuit-shell/src/plugins/builtin/**`, excluding agent-panel and
notifications. If two D lanes need the same new directory, the orchestrator
assigns exact file lists before work starts.

### D1: bar

- Wrap the current TopBar as the built-in fallback `bar` plugin.
- Add manifest-backed widget slots and per-output bar instances.
- Maintain exactly one exclusion-zone owner.

### D2: compositor

- Promote `NiriState` into `services/NiriService.qml` behind the HostContext v1
  compositor snapshot contract.
- Preserve the event stream and reconciliation behavior.

### D3: desktop services

- Split audio, network, power, battery, and Bluetooth services from their
  views.
- Construct each service once and package every helper argv.

### D4: widgets and panels

- Port clock, workspaces, resources, meeting, and recording widgets into bar
  slots.
- Route their popouts through `SurfaceRouter` with mutual exclusion and
  focused-output placement.

### D5: OSD and workflow state

- Port volume, brightness, and Dictator waveform into one keep-loaded overlay
  while preserving stacking and the live waveform.
- Version recording and meeting state contracts before moving views.
- Prove with fixture state files that a shell restart cannot kill an active
  recording. Never touch the live recorder.

All D lanes must prove that per-output views do not multiply services, timers,
sockets, or IPC names. Integration uses a short shadow preview with no
production exclusive zone or service authority and captures preview-only
screenshots.

## Review and merge gate

For every lane, the orchestrator:

1. Checks the branch file list against this ownership map.
2. Reads the entire diff and every new file.
3. Rejects activation, live-session D-Bus access, untyped command execution,
   missing attribution, and contract drift.
4. Checks the lane's verification output and reruns risk-proportionate proof.
5. Sends defects to a fresh blank-context worker rather than merging a weak
   lane.
6. Merges only after review, then updates the evidence ledger with commands,
   exit codes, open issues, and review notes.
