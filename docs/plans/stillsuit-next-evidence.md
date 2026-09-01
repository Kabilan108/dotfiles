# Stillsuit Next evidence ledger

Branch: `stillsuit-next`

Activation status: Gate 1 was completed by the human on 2026-08-31. The active
system generation is
`/nix/store/nh2bvm9a083s2d3qpalrg234j6nmxprq-nixos-system-jacurutu-26.11.20260822.2c423e0`;
Waybar and the configured agent workspace are retired. Gate 2 has not been run.
The legacy Stillsuit shell remains the sole notification owner, and Stillsuit
Next remains inactive. The human approved Gate 2 on 2026-08-31, and its patch is
staged and validated but not built or activated. Only the exact disposable
shadow-preview child PIDs and their private buses were torn down during
agent-run tests.

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

Status: reviewed and merged from lane commits
`328dd555e62f3004d9bd1e9d322e43964155ccb8`,
`67a5603a65764245ae27f0a29f6cf117a26723ca`, and
`89ddd4b228593a4312c693a41deeea3e87dc2376` through merge commit
`d48bb52`.

- Added the per-output functional bar, deterministic manifest-backed slots,
  and exactly-once host-claim release after construction failure.
- The original diff was read in full and rejected because it used a
  nonexistent Loader API, did not construct a real required-property widget,
  and did not release a failed slot's host claim.
- The first correction was read in full and rejected because it added a Timer
  to every slot. The final blank-context correction uses generation-guarded
  `Qt.callLater`, retains each component for the slot lifetime, cancels stale
  completions, injects the exact owning service at construction time, and has
  no per-output timer.
- The static and real-QML fixtures pass in isolation and merged main. They
  cover a required `service` property, replacement during queued construction,
  no stale object/release, exactly one live child, and exactly one release on
  a real construction failure. The expected deliberate missing-service case
  emits one contained QML warning.

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

Integration resolution: the composition root now constructs one `NiriService`
and injects its adapter into both HostContext and SurfaceRouter.

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

Status: reviewed and merged from lane commits
`dda9979e113fde525b34813cba5ef8248ce68006`,
`04ce5376994782ac5823066417536f49a0ec49db`, and
`e92903df8d62188dd55dab2f90c833a38c1e72ca` through merge commit
`5fd67e8`.

- Added one global workflow aggregate for versioned recording, meeting, and
  Dictator state plus one global OSD observer and per-output presentation-only
  overlays.
- The original cumulative diff was read in full and rejected because it used
  stale D4 service contracts and placed workflow/OSD authority in per-output
  objects. A blank-context correction centralized those contracts.
- That correction was read in full and rejected because Dictator waveform
  updates did not schedule repaint and a meeting-completion timer could run
  forever. The final correction repaints on scan-position changes and bounds
  the completion/error visibility timer.
- The merged fixture proves fixed recorder/open argv, schema-version
  containment, one workflow and one OSD service across two output views,
  Dictator socket singleton behavior, waveform updates, meeting visibility,
  and survival of an externally-owned recorder PID across shell teardown and
  recreation. It never touches the live recorder, meeting worker, or Dictator
  socket.
- The broad ShellCheck gate later found two informational `! rg` forms that
  could bypass `errexit`; the orchestrator replaced them with explicit guarded
  failures and reran the fixture and ShellCheck successfully.

## Integration verification

Status: all accepted lane work is integrated; the module remains default-off
and neither human gate has been run.

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
- Registered all 15 built-in plugins in deterministic ID order. External bar
  ownership now selects no bar; `stillsuit.builtin-bar` resolves to the actual
  `stillsuit.bar` manifest.
- Added the Nix-built recorder helper. Its wrapper exposes only the fixed Nix
  Python and `gpu-screen-recorder` path, while its optional meeting helper is
  replaced with the canonical absolute `/home/kabilan/bin/meeting-minutes`
  artifact. Recorder and meeting status writers now emit `schemaVersion: 1`.
- Replaced the inert compositor snapshot with the real global Niri adapter,
  wired widget registrations and exact singleton services into the functional
  bar, and retained the functional built-in bar as the production fallback.
- The first store-backed preview exposed that individually copied plugin roots
  broke reviewed imports into the shared service layer. Catalog packaging now
  preserves each nested manifest directory inside one immutable source tree;
  entry points remain relative to that manifest directory.
- That preview also exposed missing agent-widget singleton acceptance and the
  per-output OSD `outputId` contract. Both were corrected and their targeted
  fixtures rerun before rebuilding.
- The service installs the store-backed shell source at canonical Quickshell
  config name `stillsuit-next` and starts `--config stillsuit-next`. The Nix
  store output path no longer becomes config identity; generated instance IDs
  remain diagnostic only.

Current verification:

- Draft 2020-12 schema validation over all built-ins, exit 0: 15 valid,
  distinct IDs.
- Full isolated fixture ladder, exit 0: host/core 67 checks, agent panel, all
  three private-D-Bus notification suites, D1 static and real-QML, D2, D3, D4,
  and D5. The first aggregate invocation exited 126 because the D1 static
  driver is interpreter-invoked but not executable; the explicit Bash rerun
  and all remaining fixtures exited 0.
- `bash -n` and Nix-shell ShellCheck over all 12 shell drivers/helpers, exit 0
  after the D5 harness correction.
- Python compilation and Ruff checks over the recorder/meeting writers and D5
  socket fixture, exit 0. Ruff formatting passes the modified recorder and
  socket fixture; an unrelated pre-existing `meeting-minutes` formatting
  suggestion was left untouched.
- `nixfmt --check`, `nix flake check --no-build`, Jacurutu toplevel `drvPath`
  evaluation, shell package build, and force-enabled Jacurutu no-link build
  exited 0 on the staged tree. Only existing nixpkgs deprecation warnings were
  emitted.
- The generated force-enabled catalog contains 15 enabled plugins, selected
  bar `stillsuit.bar`, and the restricted recorder helper closure.
- A private-D-Bus/private-XDG shadow preview using the Nix-built store package
  and canonical `--config stillsuit-next-shadow-preview` identity exited 0:
  one screen, 11 global service objects, all 15 plugins loaded, real bar active
  without fallback, no plugin errors, no notification D-Bus owner, and mutual
  exclusion moved the open surface from audio to resources. The exact preview
  PID and its private bus were torn down after each run.
- The preview initially used the host's placeholder `/etc/dbus-1/session.conf`
  and exited before launch because that file has no listen address. The
  corrected run used the reviewed private fixture bus configuration.
- Runtime screenshot inspection is not accepted as visual proof: the session
  was already covered by swaylock, so both captures contained only its lock
  surface. The orchestrator did not unlock or disturb it. Repeating the visual
  checklist after the human unlocked the session is recorded below.
- The unlocked shadow-only visual review used a clean archive of
  `e07968b6b6a38d327961f6c92c713d73de74e58e`, the Nix-built store shell,
  private XDG roots, a private session bus, external notification ownership,
  and canonical `--config stillsuit-next-shadow-preview` identity. It did not
  activate a generation or change a live service.
- The first unlocked launch did not reach Wayland because the private runtime
  root made relative `WAYLAND_DISPLAY=wayland-1` resolve to the wrong socket.
  The exact child had already exited; the runner was corrected to use the
  existing absolute Wayland and Niri socket paths before retrying. No live
  process or configuration was touched by that correction.
- The successful unlocked preview reported two screens, 11 singleton service
  objects, six surface objects, and all 15 plugins loaded without plugin
  errors. The real `stillsuit.bar` was loaded without fallback, the private bus
  had no `org.freedesktop.Notifications` owner, and opening resources closed
  and unloaded the previously open audio panel.
- Cropped screenshots were inspected at original detail. The Stillsuit shadow
  bar was visible on both `DP-4` and `eDP-1`; each output showed three populated
  workspace indicators. The audio panel rendered its output/input devices,
  volume control, and mute action on `DP-4`. The resources panel changed CPU
  from 26 percent to 17 percent across four seconds while memory remained at
  74 percent, providing visual evidence that live sampling was advancing.
- The exact successful preview PID `1214947` and its private bus were stopped,
  and no shadow instance remained. The legacy shell and notification owner
  remained PID `63916`, Waybar remained active, and the compositor overview and
  focus were restored after inspection. Privacy-sensitive temporary screenshots
  were deleted after this ledger entry was committed.
- Applied Gate 1 workspace and Waybar patches followed by the Gate 2 cutover
  patch only inside a disposable archived tree. `git apply` checks, Niri
  validation, Nix formatting, and flake evaluation exited 0; the tracked live
  Niri file was not changed. The reverse sequence also passed its apply checks,
  Niri validation, and byte comparison with both original preimages.
- Every `/tmp/stillsuit-lanes/*` worktree reported clean before removal and was
  pruned. The pre-existing unrelated `skill-audit` worktree was preserved.

## Independent Claude review recovery

The independent review in Claude session
`d443951d-085e-47a9-9c14-29beaa773fd0` stopped when the account reached its
rate limit. Its primary record and four child records were recovered read-only
on 2026-08-31. Three child reviewers completed. The Nix reviewer reached the
end of its command-level inspection but did not produce a final report.

The deduplicated findings, source locators, repair order, reviewer completion
status, and recovery limitation are recorded in
`docs/plans/stillsuit-next-claude-review-recovery.md`.

The recovered review blocked Gate 2 on this repair list:

- pass the real bar output identity into the workspaces widget;
- invalidate an in-flight selected-bar load before fallback activation;
- contain screen-reconciliation failures to one plugin;
- align the `meeting_queued` recorder phase with the service parser;
- reload resource file views and derive live recording elapsed time; and
- give the recorder-to-meeting enqueue path an exact executable closure.

The security-focused reviewer passed the agent-panel and fixed-action IPC
boundaries with no blocker or major finding. The host-core reviewer and primary
session both judged Gate 1 technically safe because it does not enable
Stillsuit Next. No gate was run during recovery.

Repair progress:

- A2 and A3 were implemented in isolated host-core commit `e1822e6b` and
  accepted through merge commit `60a08530`. The orchestrator read the complete
  cumulative diff before merge.
- The repair invalidates only the in-flight selected-bar load from the catalog
  document-failure path, so component-error fallback paths cannot decrement the
  pending-load count twice. Screen reconciliation now contains a failed
  contribution to its plugin and continues with later plugins.
- The new regressions failed on `8da6ac7f` before the fix. The lane reported the
  existing 67 core checks plus 13 repair checks passing. The orchestrator then
  reran the complete Lane B fixture independently after review; it exited 0
  with the same 67 plus 13 checks.
- A1, A4, A5, and A6 were implemented in isolated bar/workflow commit
  `e193d6fd` and accepted through merge commit `dd5796e4`. The orchestrator
  read the complete cumulative diff before merge, then independently reran the
  real two-output D4 fixture and the real recorder/meeting D5 fixture; both
  exited 0.
- The bar now supplies `outputId` at construction to every built-in widget;
  recorder state accepts `meeting_queued`; resource file views reload before
  reads; and the singleton recorder service derives a live elapsed value while
  preserving exact paused-time arithmetic.
- The D1 real-QML fixture was updated in integration commit `0058fe54` to assert
  the same constructor-time `outputId` contract. Its static and QML runs both
  exited 0 after the orchestrator reviewed the integration diff.
- A7, N1, and N2 were implemented in isolated Nix commit `3fa5bb71` and
  accepted through merge commit `a664a2f7`. The orchestrator read all nine
  changed files before merge.
- The store-backed enqueue helper pins Python and `systemctl`; the recorder
  wrapper's PATH still contains only `gpu-screen-recorder`. Independent builds
  showed exactly Python and `systemd-minimal` as the enqueue helper's direct
  references, and the empty-PATH/fake-systemctl enqueue fixture exited 0.
  Deterministic valid registry evaluation exited 0 twice; malformed JSON
  failed with both its manifest path and the underlying parse error. Nix
  formatting, recorder/helper builds, commit diff checks, and
  `nix flake check --no-build` all exited 0. The unsupported user-unit
  `DataDirectory` directive was removed.
- All recovered repair items are now merged. The complete post-integration
  fixture ladder and disposable forced-enabled build are recorded below. No
  gate or activation has been performed.

Post-repair integration verification:

- Draft 2020-12 validation over all 15 built-in manifests exited 0. Static
  duplicate-ID and four-target IPC checks, expected pre-Gate-1 workspace
  containment, eight-file provenance-header checks, and the no-runtime-upstream
  dependency check exited 0. The first inline static harness exited 1 because
  its IPC regex was over-escaped; the corrected identical assertions exited 0.
- The complete isolated fixture ladder exited 0: host boot; 67 core-contract
  checks; 13 host-repair checks; agent panel; all three private-D-Bus
  notification suites; D1 static and real-QML; D2 compositor; D3 services; D4
  real two-output widgets; and D5 recorder/workflow behavior.
- D3 initially exited 1 because its direct widget construction had not been
  updated for A1's required `outputId`. Integration commit `e82aed8` supplies
  and asserts two distinct output identities. The orchestrator read the diff,
  reran D3, and accepted the fixture-only correction.
- Bash syntax and Nix-shell ShellCheck over all 12 shell drivers/helpers exited
  0. The first syntax command exited 127 because it used the stale helper path
  `bin/stillsuit-agent-panel`; the corrected package-local path exited 0.
- Python compilation over the recorder, meeting enqueue source, and D5 socket
  fixture exited 0. Ruff and `ty` over the two modified Python programs exited
  0. A broad Ruff run exited 1 on four pre-existing `bin/meeting-minutes`
  findings outside this branch's one added schema-version line; the same file
  exited 0 with only those unchanged `RUF046` and `DTZ006` findings excluded.
  They were not expanded into this migration.
- `nixfmt --check` over all 16 Nix files changed since the starting commit,
  the empty-PATH meeting-enqueue build fixture, two deterministic valid
  registry evaluations, `nix flake check --no-build`, and default-off Jacurutu
  closure evaluation exited 0. Malformed JSON evaluation exited 1 as expected
  with both the manifest path and underlying parse error.
- The first main-source meeting fixture invocation exited 1 because
  `builtins.getFlake` tried to copy the ignored live Unix socket below the dirty
  checkout. Reusing the clean repair worktree only for the pinned nixpkgs input
  while retaining main-checkout fixture sources exited 0.
- The first disposable no-link build exited 0 but was rejected: its temporary
  Git repository still had the gate patches uncommitted, so a post-build option
  audit proved Nix had evaluated `enable = false`. Committing the temporary
  changes then exposed a real defect in the staged Gate 2 patch: its zero-context
  hunk placed enablement inside the Nix `let` block as unused local bindings.
- Integration commit `0e0f202` moves that hunk below `in {`. A fresh archive of
  current `HEAD` accepted both Gate 1 patches and the corrected Gate 2 patch,
  passed `git diff --check`, Niri validation, Nix formatting, and forced-enabled
  flake evaluation, and proved `enable = true`, Stillsuit bar and notification
  ownership, catalog presence, and user-unit presence before the final build.
- The actual forced-enabled Jacurutu closure evaluated to
  `/nix/store/gcjy1qhxm8bd15fm8nmp79qvkk2bhwbk-nixos-system-jacurutu-26.11.20260822.2c423e0.drv`;
  `nix build --no-link` exited 0. The built catalog has 15 unique plugins and
  selected bar `stillsuit.bar`. The generated unit uses canonical config ID
  `stillsuit-next`, has no `DataDirectory`, and passed `systemd-analyze --user
  verify` with its packaged user-unit search path. The built recorder wrapper
  exposes only `gpu-screen-recorder` on PATH and references the store-backed
  meeting enqueue helper.
- One unit inspection and verification attempt used the derivation's output
  directory as if it were the unit file and exited 4/1. Resolving its contained
  `stillsuit-shell.service` and the packaged systemd user-target path produced
  the successful checks above.
- The three clean repair worktrees were removed and their merged temporary
  branches deleted. All disposable cutover archives and the temporary Python
  bytecode cache were deleted after evidence capture; their source remains in
  Git and the successful build outputs remain in the Nix store. The pre-existing
  `skill-audit` worktree and unrelated untracked
  `agents/skills/html-plans/todos.md` were preserved.

## Secondary review repairs

The non-blocking findings retained by the resumed Claude review were completed
before requesting Gate 2. Four repair lanes started from Gate 1 commit
`9c388f73`, received blank context and explicit file ownership, and performed
no activation or live desktop changes. The orchestrator read every complete
lane diff before merging it:

- host runtime `637791b0`, merged by `067795f6`;
- notifications `c7840e5c`, merged by `fa4cb1a1`;
- schema and theme `a097144c` plus fixture-isolation correction `c59d1ae2`,
  merged by `8f0f7a9a`; and
- services and workflows `a153b368`, merged by `08dca3d7`.

The host lane preserves per-plugin failures when adding a catalog-document
failure and rehomes an open global surface when its output disappears. The
notification lane releases final evicted live references, makes clear-all
durable before returning, and renders sender-controlled bodies as plain text.
The schema/theme lane enforces reverse manifest kind constraints in both schema
and runtime validation, requires the schema's `identity` and `palette` records
at runtime, and replaces the missing cursor accent role. The service lane adds
bounded Niri reconnect backoff and reconciliation timeouts, proves missing-at-
startup recorder-file discovery against the pinned Quickshell behavior, fixes
the pinned normalized battery and Wi-Fi unit contracts, and migrates the exact
historical pre-version meeting state in memory.

Two review interventions were required before acceptance. The first
schema/theme draft expanded into an unnecessary hand-written copy of the theme
schema and was narrowed to the runtime boundary actually at issue. Its first
committed fixture inherited the real home directory and used busy polling; the
follow-up commit gave it a private home and bounded sleeps. The other three lane
diffs were accepted after full review and focused reruns.

The two deliberately retained notes were also assessed. `CompositorAdapter`
profiling measured about 0.20 ms per event at 20 windows, 0.61 ms at 100, and
5.81 ms at an artificial 1000; caching would expose mutable consumer arrays, so
no change was justified. The agent-panel check-then-kill PID recycle window
needs a pidfd-like identity primitive and was not obscured by a weaker patch.

Post-merge verification on `08dca3d7` exited 0 for the focused schema/theme
suite, Lane B (67 core and 24 repair checks), agent panel, all three
private-D-Bus notification suites, D1 through D5, Bash syntax, ShellCheck,
Python compilation, Ruff, `ty`, manifest schema validation and unique-ID
checks, `niri validate`, `nixfmt --check`, and `nix flake check --no-build`.
The D1 QML driver initially exited 126 when invoked directly because it is not
executable; invoking its documented Bash entry point passed. Two `ty` attempts
could not discover the temporary `jsonschema` dependency; resolving its site
package directory and supplying it through `--extra-search-path` passed. These
failed invocations were harness/environment corrections, not suppressed test
failures.

A clean Git archive of `08dca3d7` accepted the Gate 2 patch only inside a
disposable repository. The patched option audit proved `enable = true`, bar
owner `stillsuit.builtin-bar`, and notification owner
`stillsuit.notifications`. Its shell package build produced
`/nix/store/v4mga6hs2nkfyqym49807ykzvix7ds5m-stillsuit-shell-0.1.0.drv`.
The forced-enabled Jacurutu closure build exited 0 with derivation
`/nix/store/8v212y04l8n8l9phq4siwp4i4vhc3h46-nixos-system-jacurutu-26.11.20260822.2c423e0.drv`
and output
`/nix/store/6nlz1x4cq38q7r6zpp4pjcab815xz7iz-nixos-system-jacurutu-26.11.20260822.2c423e0`.
The built catalog contains schema version 1, selected bar `stillsuit.bar`, and
15 unique plugins.

The generated unit at
`/nix/store/xn289ma6qhbrx5mr85rfv9za3yhm6lp7-stillsuit-shell.service/stillsuit-shell.service`
uses canonical config `stillsuit-next`, sets shadow mode off, has no
`DataDirectory=`, and passed `systemd-analyze --user verify` with the packaged
systemd user targets. Two earlier verifier attempts exited 1 because their
search paths omitted the systemd package's `basic.target`; adding the complete
packaged target path produced the successful audit.

The human later supplied the resumed primary Claude report, which independently
accepted every A1-A7/N1-N2 repair and reported no remaining blocker or major.
A Tracer sync retry spent its scan without finding a session to import and
finished with zero created, updated, skipped, or errored records. The supplied
report is therefore recorded as human-provided evidence rather than claimed as
a newly recovered transcript.

All four secondary worktrees were clean before removal. Their merged temporary
branches and the disposable build/audit files were deleted; the pre-existing
`skill-audit` worktree and the unrelated main-checkout changes remained
untouched. A final main-checkout check proved the canonical staged cutover patch
still applies cleanly and the aggregate Gate 1-to-current diff has no whitespace
errors. The live boundary remained unchanged: only legacy Stillsuit PID `63916`
was running and owned `org.freedesktop.Notifications`; Waybar and the Next unit
were inactive and absent from the active generation.

## Human-owned gates

Gate 1 was approved by the human on 2026-08-31. Its workspace-removal and
Waybar-disable patches are committed in the main checkout. The changed Niri
configuration passed `niri validate`, the Waybar module passed `nixfmt
--check`, and `nix flake check --no-build` exited 0. The human then ran the
repository-required rebuild and generation switch. `/run/current-system`
resolves to the generation recorded above; `waybar.service` reports `inactive`
and `not-found`; and the compositor reports no named `agent` workspace. One
legacy `stillsuit` instance remains at PID `63916` and still owns
`org.freedesktop.Notifications`, while `stillsuit-shell.service` is inactive.
This is the intended boundary after Gate 1. Gate 1 is complete.

The human approved Gate 2 on 2026-08-31. The canonical cutover patch applied
cleanly to the main checkout. It enables the Stillsuit module below the Nix
module's `in {`, assigns the built-in bar and notification owners, removes the
legacy Niri startup declaration, adds the agent-panel window rule, and retargets
the five shell bindings to `stillsuit-next`. `git diff --check`, `niri
validate`, `nixfmt --check`, and `nix flake check --no-build` exited 0.
The reverse patch check also exited 0. Direct evaluation of the staged Jacurutu
configuration returned `enable = true`, bar owners
`["stillsuit.builtin-bar"]`, and notification owners
`["stillsuit.notifications"]`.

No build, generation switch, service restart, process kill, or notification
ownership change was performed while staging the gate. Legacy Stillsuit PID
`63916` remains the only legacy instance and notification owner;
`stillsuit-shell.service` remains inactive in the current generation. The next
human action is the build-only command. After it succeeds, the prepared bounded
PID, D-Bus-name, systemd, IPC-readiness, and ownership checks govern the switch.

## Remaining work

- Run the Gate 2 build-only command from the prepared handoff. Do not use
  `rebuild` or switch the generation yet.
- After the build succeeds, run the exact ordered single-owner handoff rather
  than an unbounded or newest-instance selection.
