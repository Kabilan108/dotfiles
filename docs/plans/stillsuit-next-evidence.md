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

- `nixfmt --check` on all Lane A Nix files and `home/default.nix`, exit 0.
- `check-jsonschema` on the merged builtin manifests, exit 0.
- Canonical theme evaluation checked against `theme.v1.json`, exit 0.
- Stylix's pinned `catppuccin-mocha.yaml` was inspected; the generated
  `system/name/author/variant/palette` shape matches its current schema.
- Exact extracted license notice compared with
  `/vault/repos/omarchy-quattro/LICENSE`, exit 0.
- Positive enabled-module fixture with capability `notification-server`, exit
  0. The same service with capability `notifications` exits 1 with the expected
  owner assertion.
- Lane package build from the clean worktree, exit 0.
- Main-checkout package build including the merged Lane C source, exit 0.
- Main-checkout `nix flake check --no-build`, exit 0.
- Main-checkout Jacurutu toplevel `drvPath` evaluation, exit 0.
- Main-checkout `nix build --no-link
  .#nixosConfigurations.jacurutu.config.system.build.toplevel`, exit 0.
- One initial impure package-expression build exited 1 because
  `builtins.getFlake` tried to copy an ignored live Unix socket below the dirty
  main checkout. The corrected expression used the clean lane worktree only
  for the pinned nixpkgs input and the main checkout for the package source;
  it exited 0.

Review notes:

- The first review rejected the attribution document because it linked to,
  but did not retain, the binding MIT notice. A fresh blank-context correction
  lane added the exact notice and adapted-file inventory.
- A second fresh correction aligned the notification-owner assertion with
  Lane E's actual `notification-server` capability.
- The orchestrator read the full cumulative diff, reran the module, package,
  schema, theme, provenance, flake, closure, and build checks, and imported the
  module without enabling it.
- Flake evaluation emitted only the existing `stdenv.isLinux` and
  `stdenv.isDarwin` deprecation warnings.

Open issues:

- Desktop plugin registration and its final exact runtime closure remain
  integration work after the D lanes are accepted.
- No ownership selection or service enablement has been added; Gate 2 remains
  human-owned.

## Lane B: host core and interaction primitives

Status: pending.

Built: pending.

Verification: pending.

Review notes: pending.

- `packages/stillsuit-shell/src/tests/run-lane-b-fixtures.sh`, exit 0 in both
  the final lane worktree and merged main checkout. The real isolated host
  fixture passed and the deterministic core fixture reported 67 checks.
- Lane-B fixture ShellCheck, exit 0.
- Fixture theme validation against `theme.v1.json`, exit 0.
- Merged builtin manifest validation against `manifest.v1.json`, exit 0; the
  two current IDs are distinct.
- Provenance-header query over the four adapted interaction primitives, exit
  0; the forbidden-runtime query found no matches, exit 1 as expected.
- Cumulative lane ownership and `git diff --check` gates, exit 0.
- Merged Lane C agent-panel fixture, exit 0.
- Merged notification engine, shadow-owner, and view-topology fixtures, exit
  0 under their private session buses and XDG roots.
- Merged `nixfmt --check`, `nix flake check --no-build`, Jacurutu toplevel
  `drvPath` evaluation, shell package build, and Jacurutu no-link toplevel
  build, exit 0.
- `git apply --check` for the staged workspace-removal patch and
  `niri validate --config` for the unchanged live-config preimage, exit 0.

Review notes:

- The original lane diff was read in full and rejected. It selected only one
  primary surface kind, assigned per-output properties after construction,
  omitted the plugin-owned service injection required by Lane E, returned a
  literal agent status, left live dependants after runtime unload, and did not
  expose shadow mode to the built-in fallback bar.
- A fresh blank-context, high-effort correction added multi-contribution
  routing, constructor-time injection, dependency containment/recovery,
  structured helper results, and fallback shadow settings. Its cumulative
  diff was read in full.
- That correction was rejected once more because queued opens were never
  resumed after a non-keep-loaded route's service became ready, and removing
  the selected screen left a per-output route logically open but invisible.
  A second fresh blank-context correction added deterministic retry and
  coherent open-surface migration. Its two-file diff was read in full and the
  complete lane suite was rerun independently before merge.
- One combined static-check shell harness exited 127 because its inline quoting
  was malformed. No repository file changed. The same checks were rerun with
  literal manifest targets and exited 0.
- One `nixfmt --check` invocation exited 1 because it used the stale path
  `home/desktop/wayland/niri/default.nix`. The corrected compositor path exited
  0; no formatting change was needed.
- The stale-workspace query now matches only the deliberately untouched live
  Niri preimage. The reviewed removal remains staged as a patch for Gate 1.

Open issues:

- Desktop service/bar wiring from the D lanes and its full-host fixtures remain
  orchestrator integration work.
- Lane D must replace the built-in fallback marker and inert compositor
  snapshot with the reviewed desktop implementation before either human gate.

## Lane C: agent quake panel

Status: pending.

Built: pending.

Verification: pending.

Review notes: pending.

- `bash -n` on the helper and fixture suite, exit 0.
- `nix shell nixpkgs#shellcheck --command shellcheck <helper> <fixture>`,
  exit 0.
- `packages/stillsuit-shell/src/plugins/builtin/agent-panel/tests/run.sh`,
  exit 0. This includes hostile configuration, extra arguments, a toggle
  storm, delayed Niri/Ghostty disappearance, unrelated-PID protection, and an
  isolated real-tmux prefix-decoy regression.
- `check-jsonschema` against `manifest.v1.json`, exit 0.
- Static duplicate-plugin-ID query over all current builtin manifests, exit 0.
- Applied the documented window rule and binding only to a temporary archived
  configuration and ran `niri validate --config <temporary-config>`, exit 0.
  The live `config.kdl` was not edited.
- Main-checkout `nix flake check --no-build`, exit 0.
- Main-checkout Jacurutu toplevel `drvPath` evaluation, exit 0.
- Main-checkout `nix build --no-link
  .#nixosConfigurations.jacurutu.config.system.build.toplevel`, exit 0.
- `git diff 5d0b515..stillsuit-next-lane-c --check`, exit 0.

Review notes:

- The first lane diff was rejected because tmux `-t stillsuit-agent` accepted
  prefixed sessions and window/PID shutdown removed state before the old
  process was proven gone. A fresh blank-context correction lane changed every
  tmux target to exact `=stillsuit-agent` matching and added bounded shutdown
  barriers.
- The orchestrator read the corrected cumulative diff and independently reran
  all checks above before merging.
- The helper package must be installed in the Home Manager profile as well as
  placed on the shell's restricted PATH; otherwise Niri cannot resolve the
  staged literal command.

Open issues:

- The agent-panel plugin is registered and its helper integration is complete;
  its full-host path will be exercised in the final shadow preview.
- `docs/plans/staged-niri-changes.md` remains documentation-only. Its rule and
  binding are not part of the live compositor configuration.

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

Status: original diff reviewed in full and rejected. A fresh blank-context
correction is in progress. The original used a nonexistent Loader API, did not
construct a real required-property widget in its fixture, and did not release
the host claim when a slot failed.

## Lane D2: compositor

Status: reviewed and merged from lane commits
`080dbf203584519d07f9a62cb56a19684c60aedd` and
`2984c9215ef02334489cb3040e9f775389acf22e`.

- Added one global Niri service behind a read-only compositor adapter, with a
  fixed-argv event stream, bounded reconciliation, reconnect, and plain
  output/workspace/window snapshots.
- The original diff was read in full and rejected because it modeled real
  `niri msg -j outputs` as an array instead of its connector-keyed object and
  allowed failed/empty partial refreshes to overwrite a coherent snapshot.
- The corrected service normalizes keyed maps to a deterministic array,
  accepts only a completed normal/zero-exit triplet as one generation, keeps
  the complete last-good snapshot after nonzero/empty/malformed generations,
  and recovers atomically.
- The D2 fixture passed independently and in merged main. It proves one service
  and adapter, four exact Niri argv forms, failed/malformed containment,
  recovery, and the absence of binding-loop/type/reference errors.
- The merged manifest/duplicate-ID and all prior fixture gates, `nixfmt
  --check`, `nix flake check --no-build`, Jacurutu `drvPath`, shell-package
  build, and Jacurutu no-link build exited 0.

Open issue: the composition root still needs to replace its frozen inert
snapshot with this adapter during orchestrator integration.

## Lane D3: desktop services

Status: reviewed and merged from lane commits
`9c2281a44807d79c58669d0a432dc969ae74d023` and
`920bf8f5c16a0bc41d14644ec753b968c0c1d328`.

- Added global, versioned audio, network, power-profile, battery, and Bluetooth
  services with per-output widgets and routed panels where applicable. The only
  process helper uses literal `powerprofilesctl get`/`set <validated-profile>`
  argv.
- The original cumulative diff was read in full. A narrow correction was
  required because owning widgets asked a dependency-only facade for their own
  plugin ID and the fixture did not directly exercise unavailable states.
- The correction makes widgets require the exact injected owning singleton,
  leaves only battery's declared power dependency in `context.services`, and
  fixtures all five unavailable contracts without touching system services.
- The corrected isolated D3 fixture, explicit QML error scan, cumulative
  `git diff --check`, merged 12-manifest schema/duplicate-ID gates, all prior
  host/plugin fixtures, `nixfmt --check`, `nix flake check --no-build`,
  Jacurutu `drvPath` evaluation, shell-package build, and Jacurutu no-link
  toplevel build exited 0.

## Lane D4: widgets and panels

Status: reviewed and merged from lane commits
`f5404417d6ad3427e83827a733da1b81f27cf89d` and
`d9561e7592927b8c75becf45f02221c5b29f7519`.

- Added clock, workspaces, resources, meeting, and recording widgets, with
  resource/meeting/recording panels routed through the typed host actions.
- Clock and resource collection each use one global versioned service shared
  by all per-output views. Meeting and recording consume only their declared
  `stillsuit.workflows` dependency.
- The original diff was read in full and rejected because it put a one-second
  Timer in every per-output clock widget. The corrected diff moved the timer to
  one global clock service, made own-service injection required, versioned the
  resource service, and made the fixture driver executable.
- The corrected isolated fixture, QML error scan, five-manifest validation,
  `git diff --check`, and the merged main static/fixture ladder exited 0. The
  fixture proves one clock service and one resource service shared across two
  output views, workspace/column projection, typed panel routes, and workflow
  state propagation.
- Merged-main `nixfmt --check`, `nix flake check --no-build`, Jacurutu toplevel
  `drvPath` evaluation, shell-package build through its evaluated Home Manager
  option, and Jacurutu no-link toplevel build exited 0.
- An initial package build command exited 1 because the flake does not export a
  top-level `packages.x86_64-linux.stillsuit-shell` attribute. The corrected
  evaluated Home Manager package path above exited 0; no repository or live
  system state changed.

## Lane D5: OSD and workflow state

Status: lane commit `dda9979e113fde525b34813cba5ef8248ce68006`
reported with isolated workflow, state-version, socket-singleton, helper-argv,
and recorder-survival fixtures. The orchestrator review gate is pending.

## Integration verification

Status: foundational A/B/C integration complete; desktop integration pending
accepted D-lane commits.

- Added a Nix-built agent-panel helper with an exact restricted closure and
  installed it in the profile only when the default-off module is enabled.
- Added typed model/effort/tier defaults, only-if-absent runtime config
  materialization, exact host environment names, shadow mode, state/runtime
  directories, and deterministic catalog reconciliation.
- The helper derivation build, `git diff --check`, `nixfmt`, and
  `nix flake check --no-build` exited 0.
- The first forced-enabled Jacurutu closure build exposed that a `writeText`
  store path cannot be parsed as Stylix YAML during module evaluation. The
  Base16 projection was changed to the equivalent already-parsed attrset.
- A second forced-enabled Jacurutu closure build from the staged git tree
  exited 0. This built only a disposable closure; it did not activate, switch,
  restart, or signal any live service.

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

- Complete and merge Lanes D1 through D5 through the review gate.
- Run the integration verification ladder.
- Prepare both human-owned gates without running them.
