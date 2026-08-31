# Stillsuit Next evidence ledger

Branch: `stillsuit-next`

Activation status: not performed. No NixOS or Home Manager generation has been
rebuilt or switched. No live shell, compositor, bar, notification daemon,
recorder, meeting worker, lock service, or polkit service has been restarted or
killed.

## Inputs and contract freeze

- Execution handoff read in full:
  `docs/plans/stillsuit-next-execution.md`, 285 lines.
- Architecture artifact v5 read in full from its exact raw PageBin URL. The
  downloaded artifact and local
  `docs/plans/omarchy-quattro-shell-adoption.html` both have SHA-256
  `40179ee08b163cbe62afac4dbac33e81167ad9fed8ce83e31b4a19cafbfae4ab`.
- Compatibility note read in full:
  `docs/plans/quickshell-compat-note.md`, 97 lines. Verdict:
  `OK-with-workarounds`.
- Upstream reference inspected read-only at tag `v4.0.0`, commit
  `f0020448ca87329199de7cb12f2015ebc4a3e5e7`.
- Starting branch HEAD:
  `bb167a96941d1f4e4265a6ddd8c928c81edd0646`.
- Unrelated untracked user file preserved:
  `agents/skills/html-plans/todos.md`.

Phase 0 deliverables:

- `packages/stillsuit-shell/schemas/manifest.v1.json`
- `packages/stillsuit-shell/schemas/theme.v1.json`
- `packages/stillsuit-shell/docs/host-contract.md`
- `docs/plans/stillsuit-next-lanes.md`
- this ledger

Read-only runtime baseline:

- `bin/stillctl status`, exit 0: bar visible, Niri event stream connected,
  recorder idle, prior meeting job complete, and all reported panels closed.
- `qs list --all`, exit 0: one Stillsuit instance.
- `systemctl --user is-active waybar.service`, exit 0: `active`. The existing
  double-bar ownership hazard remains present and untouched.
- `busctl --user --no-pager status org.freedesktop.Notifications`, exit 0: the
  Stillsuit Quickshell PID is the sole reported owner.
- `niri msg --json outputs`, exit 0: two active outputs. Hardware identifiers
  are intentionally not copied into this ledger.

Phase 0 verification:

- Direct `python3` schema check, exit 1: the base interpreter did not have the
  `jsonschema` module. No repository change resulted.
- `uv run --with jsonschema python -` schema and fixture check, exit 0: both
  files pass the Draft 2020-12 metaschema; one manifest and one theme pass;
  six invalid manifests and one invalid uppercase-color theme are rejected.
- `jq empty` on both schemas, exit 0.
- Manifest invariant query for host API `1`, six known kinds, and required
  contribution scope, exit 0.
- `git diff --check` over all five intention-to-add files, exit 0.

Phase 0 review notes:

- The newer execution handoff overrides the architecture artifact's legacy
  backend sketch. The frozen contract has no `src/legacy`, backend switch, or
  per-provider switch.
- The manifest includes an explicit per-kind `scope` map because one plugin may
  contain a global service and a per-output widget.
- Host load-time validation rejects surplus known entry-point/scope keys that
  do not match a declared kind. The schema handles required-kind presence and
  path/type validation.
- Lane C cannot edit Lane A files. It reports its exact Nix wiring request for
  orchestrator integration after both diffs pass review.

## Lane A: Nix package, module, and theme

Status: pending.

Built: pending.

Verification: pending.

Review notes: pending.

Open issues: none recorded.

## Lane B: host core and interaction primitives

Status: pending.

Built: pending.

Verification: pending.

Review notes: pending.

Open issues: none recorded.

## Lane C: agent quake panel

Status: pending.

Built: pending.

Verification: pending.

Review notes: pending.

Open issues: none recorded.

## Lane E: notification engine

Status: pending.

Built: pending.

Verification: pending.

Review notes: pending.

Open issues: none recorded.

## Lane F: agent-workspace removal

Status: pending.

Built: pending.

Verification: pending.

Review notes: pending.

Open issues: none recorded.

## Lane D1: bar

Status: blocked on Lane B compiling.

## Lane D2: compositor

Status: blocked on Lane B compiling.

## Lane D3: desktop services

Status: blocked on Lane B compiling.

## Lane D4: widgets and panels

Status: blocked on Lane B compiling.

## Lane D5: OSD and workflow state

Status: blocked on Lane B compiling.

## Integration verification

Status: pending.

Static, Nix, isolated-runtime, notification, Niri, and preview evidence will be
recorded here with exact commands and exit codes.

## Human-owned gates

Gate 1, workspace removal and Waybar ownership, has not been run. Exact apply
and rollback commands will be prepared after integration proof.

Gate 2, Stillsuit Next process and notification cutover, has not been run and
will not be run during this execution. The final ledger will contain an ordered
stop, PID-exit wait, D-Bus-name release wait, start, and IPC-readiness procedure
plus rollback.

## Remaining work

- Complete and merge Lanes A, B, C, E, and F through the review gate.
- Complete and merge Lanes D1 through D5 after Lane B compiles.
- Run the integration verification ladder.
- Prepare both human-owned gates without running them.
