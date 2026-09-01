# Stillsuit Next evidence ledger

Branch: `stillsuit-next`

Activation status: Gates 1 and 2 were completed by the human on 2026-08-31. The
active system generation is
`/nix/store/6nlz1x4cq38q7r6zpp4pjcab815xz7iz-nixos-system-jacurutu-26.11.20260822.2c423e0`;
Waybar and the configured agent workspace are retired. Stillsuit Next PID
`1370585` is the sole Quickshell instance and notification owner. The legacy
shell is absent.

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
`stillsuit-shell.service` remains inactive in the current generation.

The human then ran `sudo nixos-rebuild build --flake .#jacurutu`; it exited 0
and produced
`/nix/store/6nlz1x4cq38q7r6zpp4pjcab815xz7iz-nixos-system-jacurutu-26.11.20260822.2c423e0`,
the same closure as the disposable forced-enabled proof. The `result` symlink
resolves to that exact output. The immediate pre-handoff check found exactly
legacy PID `63916`, confirmed that it owns
`org.freedesktop.Notifications`, found no other Quickshell instance, and found
the Next unit inactive and absent from the active generation. A direct
config-scoped Next query was unavailable because the current generation does
not install that config; the corrected all-instance query passed.

The prepared bounded PID, D-Bus-name, systemd, IPC-readiness, and ownership
checks governed the single-owner switch. The human ran the prepared script. It
stopped legacy PID `63916`, observed notification-name release, and activated
the built generation. The new user unit started as PID `1370585` and returned
`ok` from its IPC readiness endpoint.

The original final legacy-absence assertion then exited on a `jq` parse error.
This was a command-sheet defect, not a shell failure: after activation,
Quickshell 0.3 prints a human "No running instances" message instead of JSON
for a config-scoped query whose config is no longer installed. No rollback was
performed. The corrected all-instance assertion found exactly one Quickshell
process, confirmed that its PID matches systemd and its config path is
`stillsuit-next`, and confirmed that the same PID owns
`org.freedesktop.Notifications`. IPC reported `ready = true`, two screens, the
real `stillsuit.bar` loaded without fallback, and zero plugin errors. Gate 2 is
technically complete.

The human then confirmed that `Mod+A` opens audio, `Mod+N` opens notifications,
and `Mod+Grave` opens the agent panel with its tmux session preserved across
window closes. Read-only output captures independently showed the live bar on
both `DP-4` and `eDP-1`, with populated workspace indicators and resource
widgets. Cropped bar and agent-panel captures were deleted after inspection.

The human noted that the agent-panel window opens more slowly than desired. A
controlled open/close measurement restored the prior focus and measured 39 ms
for IPC dispatch, 38-43 ms for helper status, and 429 ms until Niri mapped the
window. The helper intentionally closes Ghostty on hide and starts a fresh
Ghostty window on open; only the tmux session persists. The fresh terminal
window accounts for nearly all measured latency. No window-lifecycle redesign
was added during gate closure.

After visual acceptance, the disposable `result` symlink and one-off
`gate-2-switch.sh` were removed. The canonical command sheet remains in
`docs/plans/stillsuit-next-human-gates.md`.

## Agent-panel reopen optimization

The human requested a focused agent-panel latency repair after the live visual
gate. A blank-context worker owned only the helper, its focused fixtures, and
the plugin README in clean worktree `/tmp/stillsuit-agent-panel-optimization`.
The worker committed `cae606e3`; the orchestrator read the complete diff before
merging it as `1415d0a8`. The merged tree matches the reviewed lane commit for
all three owned files.

The helper now keeps one class-specific Ghostty process alive after its final
surface closes and asks that existing instance to create the next surface with
`ghostty +new-window`. Hiding still closes the Niri surface, while the exact
tmux target `=stillsuit-agent` remains attached by the persistent Ghostty
process. The existing lock, class checks, single-window invariant, and bounded
PID shutdown checks remain in force. The accepted tradeoff is one idle Ghostty
process while the panel is hidden; Niri has no external hide/minimize primitive,
so reopening still has to map a new surface.

The orchestrator independently checked Ghostty 1.3.1's packaged primary
documentation for class-scoped single-instance routing and
`quit-after-last-window-closed=false`, and validated a temporary config with
those exact options. Post-merge verification exited 0 for the focused
agent-panel fixtures, Lane B (67 core and 24 repair checks), Bash syntax,
ShellCheck, `nixfmt --check`, `nix flake check --no-build`, and the evaluated
Jacurutu agent-panel helper package build. `git diff --check` also passed.

No rebuild, generation switch, service restart, or live shell mutation was
performed for this optimization. The active desktop therefore still uses the
pre-optimization helper until the human chooses to rebuild. No live reopen
latency claim is made yet.

## Design-lab foundation

The human fixed inline workspaces as the production direction and authorized a
native Quickshell design lab before any panel overhaul. The lab adds a draft v2
theme contract with three levels: raw palette, semantic roles, and component
assignments. Three schema-valid candidates are available: Stillsuit Spice,
Catppuccin Mocha, and Graphite Cyan. The controls compare Inter, IBM Plex Sans,
Noto Sans, JetBrainsMono Nerd Font, FiraMono Nerd Font, IBM Plex Mono, and the
rounded and outlined Material Symbols faces. Omarchy's JetBrainsMono Nerd Font
default is included explicitly.

The lab uses mock data and imports the new shared `ShellText`, `ShellIcon`,
`ShellSurface`, `ShellButton`, `ShellToggle`, `ShellSlider`, and
`ShellBarCluster` components. It has no notification, compositor, or service
authority. It previews only inline workspaces, both live output proportions,
26-32 px bar heights, anchored and floating edge treatments, surface tokens,
typography, icon families, and motion/reduced-motion behavior. The production
v1 theme and panels are unchanged; `DESIGN.md` and the old UI demo remain in
place until the human approves the lab direction.

All three candidates passed `check-jsonschema` against
`theme.v2.draft.json`. Every new QML file parsed with Qt 6 `qmlformat`.
`nixfmt --check`, `git diff --check`, `nix flake check --no-build`, the
Stillsuit package build, the Lane B fixtures (67 core and 24 repair checks),
and the existing schema/theme suite exited 0. A separate live design-lab
Quickshell process loaded all three candidates through its IPC control and
reported a ready Loader with the expected effective font, icon, bar height,
and edge treatment for each. The production shell remained PID `1370585` and
was neither restarted nor reloaded.

JetBrainsMono Nerd Font, Inter, and IBM Plex were added declaratively to Home
Manager. For the current review, the lab uses a disposable fontconfig closure,
so no rebuild was required to launch it. A future human-run rebuild is still
required to install those fonts system-wide and will also activate the already
approved agent-panel optimization.

## Design-lab feedback pass

The human selected a Catppuccin-based baseline in the lab: Noto Sans body text,
JetBrainsMono Nerd Font telemetry, rounded Material Symbols, a 26 px anchored
bar, 0.85 panel opacity, 4 px medium radius, 0.55 motion scale, and the captured
Catppuccin color overrides. The lab now opens with that exact review preset and
offers `Your pick` controls to restore it after comparing theme defaults.

The annotated review separated OSD styling from `surface.raised`. OSDs still
consume the component-specific `component.osd.background` and border roles,
but the background is now derived exactly from `surface.panel`; they use the
medium radius rather than the lighter control/section treatment. The draft
schema now requires exact component token sets for bars, panels, controls,
notifications, and OSDs. All three candidate themes provide the OSD border and
notification state roles.

The notification preview now switches among unread, info, success, warning,
urgent, and quiet states. The network panel switches among connected, scanning,
joining, Wi-Fi-off, and failure states, including state-specific rows and empty
or error treatments. Its former outlined mystery icon is now a borderless,
right-aligned `Scan` action that enters the scanning preview state.

A second annotated pass moved the display-only Do Not Disturb control from the
network mock to the notification preview, standardized network rows on a fixed
icon column, centered the Wi-Fi-off empty state, and replaced the failure
outline with a borderless `component.panel.rowDanger` fill. Notification state
color is now contained in a small tinted icon tile instead of a detached
full-height edge stripe.

All eleven state selections were exercised through the lab IPC. Urgent/failure and
quiet/Wi-Fi-off combinations were inspected as live window captures, and the
lab was returned to unread/connected. The live Loader remained ready and
reported the saved preset values. Qt 6 `qmlformat`, `check-jsonschema`, `jq`,
Ruff, Ty with the test dependency, `git diff --check`, the schema/theme suite,
Lane B (67 core and 24 repair checks), `nix flake check --no-build`, and the
evaluated Stillsuit package build all exited 0.

After the second pass, scanning/warning, Wi-Fi-off, and failure states were
captured again from the live lab. The IPC status reported both
`panelBackground` and `osdBackground` as `#181825`; schema tests additionally
assert that relationship for every candidate theme. JSON/schema validation,
Qt 6 QML parsing, Ruff, Ty, `git diff --check`, the schema/theme suite, Lane B
(67 core and 24 repair checks), `nix flake check --no-build`, and the evaluated
Jacurutu Stillsuit package build all exited 0.

No rebuild, service restart, production-shell reload, or panel conversion was
performed. `DESIGN.md` and the old UI demo remain unchanged pending visual
approval.

## Design approval and contract lock

The human approved the native design lab with Catppuccin Mocha, Noto Sans body
text, JetBrainsMono Nerd Font telemetry, rounded Material Symbols, a 26 px
anchored bar, inline workspaces, 0.80 surface opacity, 7 px medium radius, and
0.55 motion scale. The lab's restore action is now labeled `Approved` and
restores those exact values.

The approved language gives OSDs `semantic.surface.panel` directly. The
redundant `component.osd.background` field was removed from all candidate
themes, the v2 schema, the lab resolver, and the token map. `ShellSurface`
reads the semantic panel role for OSDs, and the schema test rejects a theme
that tries to restore the retired field.

`home/desktop/wayland/quickshell/DESIGN.md` was rewritten from the approved
native lab. It now records the three-level theme model, selected typography,
metrics, surfaces, fixed inline workspace treatment, anchored bar, motion,
state treatments, and feature-ownership boundaries. It explicitly rejects the
old consolidated media/quick-settings assumption. The obsolete 1.3 MB
`ui-demo.html` bundle was deleted.

The live lab hot-reloaded and reported a ready Loader with opacity `0.8`, radius
`7`, motion scale `0.55`, and OSD role `semantic.surface.panel`. Its token map
no longer shows `osd.background`. JSON/schema validation, the explicit retired
token scan, Qt 6 QML parsing, Ruff, Ty, `git diff --check`, the schema/theme
suite, Lane B (67 core and 24 repair checks), `nix flake check --no-build`, and
the evaluated Jacurutu Stillsuit package build all exited 0. The production
shell remained PID `1370585`; no rebuild, restart, reload, or panel conversion
was performed.

## Panel inventory review

The human authorized a parallel, read-only inventory before any panel work was
turned into a backlog. Six blank-context lanes independently covered audio and
media, notifications and DND, network and Bluetooth, battery/power/resources,
the agent panel, and recording/meeting workflows. None of the lanes edited the
checkout, rebuilt the system, changed PageBin, or touched the live shell.

The orchestrator reviewed every report, checked the high-impact claims against
the production QML, service facades, Niri bindings, and helper status, and
combined the results into a compact HTML review at
`docs/reviews/stillsuit-panel-review.html`. The page separates working
capabilities, misleading or missing behavior, product choices, retained
contracts, and test limits. Its decision queue is explicitly conversational;
it does not authorize or imply backlog work.

The live Stillsuit IPC status was ready with the real bar, 15 enabled plugins,
11 global service objects, three currently instantiated surface objects, and
no reported plugin errors. The source review confirmed the highest-impact
gaps: the audio panel is not a mixer and has no current media UI; notification
history has no unread model; production Wi-Fi scan and radio controls return
`unavailable`; the battery widget reads a retired danger-token name; the
agent-panel optimization is built but not active; and recording/meeting
service actions are not exposed by the current panel.

The initial PageBin checkpoint was published before lane work at stable viewer
ID `aUkcMf4Y4DjI7DJ5QQKkcA`. Revision 2 contains the completed review at the
same stable viewer URL. `pagebin verify` reported identical local and remote
SHA-256 `247ce6dee8b1eb6dca2b158a85d0d12b79a35d3c8f507e464dc4cdfad9ce2eb4`.
The published raw page was rendered and inspected at desktop and 390 px widths:
it had no page-level horizontal overflow, clipped content, browser errors, or
console errors; its navigation anchor and collapsed evidence disclosure were
also exercised. No lazy production panel was opened, no real
recording-to-minutes job was run, and no rebuild, service restart,
production-shell reload, or panel conversion was performed.

## Remaining work

- Review the panel inventory with the human, beginning with the audio/media
  boundary. The old HTML demo is not a source of requirements, and no
  consolidated media/quick-settings panel is assumed.
- Promote the approved v2 theme and freeze shared component contracts before
  rebuilding the first approved panel.
- After a future human-run rebuild, measure the optimized agent panel's live
  reopen latency and confirm its surface, process, tmux, and termination
  invariants.
- Complete the planned 8-24 hour live soak, including output hotplug and restart
  observation. The disposable reverse patch was proven, but live rollback has
  not been exercised.
- Remove legacy Stillsuit and disabled Waybar material only after the soak and
  explicit cleanup approval.

## Interactive panel decision worksheet

The human's first-pass panel feedback was converted into a second, interactive
review at `docs/reviews/stillsuit-panel-decisions.html`. The original inventory
remains the read-only first pass. It could not host the requested picker and
copy behavior because its PageBin artifact uses the immutable `strict` sandbox;
the decision worksheet therefore has a separate `standard`-sandbox identity.

The worksheet records the settled direction without turning it into backlog
authorization: combined audio and media with legacy full-player parity,
output-device switching only, no per-app streams, and a 100% volume ceiling;
toast dismissal as archival, immediate hiding of visible banners under DND,
and bounded notification history; an allowlisted MobergAnalytics VPN toggle,
read-only visibility for other active VPNs, metadata-only Tailscale, and explicit
Bluetooth states; CPU and memory as the resource scope; removal of the agent
bar item while retaining `Mod+Grave` and persistent tmux; and restoration of
capture setup, meeting finish, durable progress/results, retry, and the older
recording indicator's visual intent.

Fifteen remaining product choices are presented as radio pickers with concise
tradeoffs: microphone controls; unread treatment; mark-read timing; expired
notification actions; notification maximum age; Wi-Fi credential ownership;
other-VPN visibility; Bluetooth audio routing; battery detail; battery-alert
ownership; power-panel access; agent geometry; recording control layout;
durable meeting access; and recording completion lifetime. Recommended defaults
generate a natural-language continuation prompt, optional recording notes are
included, and reset restores the recommendations.

Source checks confirmed that legacy `NowPlaying.qml` was a full media player,
not a summary. The pinned Omarchy Quattro v4 implementation supplies a native
common Wi-Fi credential path with explicit joining/failure state, so adapting
personal secured Wi-Fi plus a NetworkManager editor fallback is classified as a
medium implementation lift; full native enterprise and hidden-network ownership
remains a larger security and protocol surface. Current Stillsuit runtime inputs
do not include NetworkManager CLI tools, so any future helper must be explicitly
pinned and pass secrets over standard input.

`html-validate` and standalone JavaScript parsing exited 0. The published page
loaded with 15 selected defaults and a populated continuation prompt. Changing
an unread picker and adding a recording note updated that prompt; Copy reported
success; Reset restored the default and cleared the note. Desktop and 390 px
browser captures were inspected: the cards use two columns on desktop and one
on narrow screens, with no page-level horizontal overflow. Browser page errors
and console output were both empty.

The PageBin checkpoint is artifact `F19cQq1Q-H_n6T8u9dEbiw`, revision 1,
`standard` sandbox. `pagebin publish --verify` reported identical local and
remote SHA-256
`e9802b190900c3579c86f39e0688cb01891157adf3c81ce53bfeb5b6cfca2108`.
The capability URL remains in the protected local receipt and was not committed.

No panel implementation, Nix rebuild, activation, service restart, production
shell reload, or live desktop mutation was performed.

## Panel selections and recording-history pass

The human accepted all fifteen first-pass picker decisions. Audio retains
microphone level and mute without input-device switching. Notifications use a
bounded unread count, read-on-open semantics, a visible expired-action note,
and a 24-hour plus 100-item history limit. Personal Wi-Fi uses the native
Stillsuit path with NetworkManager editor fallback for enterprise and hidden
networks; other VPNs appear only while active; Bluetooth audio becomes the
default output on connect. Power uses the practical battery detail set, an
independent alert service, and bar-only access. The agent window moves to 60%
by 60%. Recording uses compact active controls, a Recent meetings section, and
an auto-closing completion view backed by durable history.

The follow-up recording note makes Obsidian the long-term meeting record and
the Stillsuit list an operational work queue. Retry is manual only. A failed row
shows an error summary plus separate Details and Retry actions. Retry reuses the
same durable job identity, increments its attempt, disables duplicate dispatch,
and returns the row to queued; the shell never starts an automatic retry.

The revised worksheet ranks queued, processing, and failed jobs ahead of
completed jobs. Completed jobs fill remaining slots, newest first. The visible
meeting list always honors a fixed row cap. When actionable jobs exceed that
cap, the newest jobs remain visible, an overflow count represents the older
jobs, and older work rolls forward as shown jobs complete. Three genuine choices
remain: the cap value, whether overflow opens capped pages or only reports a
count, and the exact completion auto-close delay.

The interactive artifact was reduced from fifteen pickers to those three
choices. Its generated prompt includes the accepted panel contracts, the fixed
manual-retry model, the three final selections, and an optional note. Changing
the row cap and entering a note updated the prompt; Copy reported success; Reset
restored the recommended eight-row cap and cleared the note. The page rendered
as a single-column layout at the narrow breakpoint without page-level horizontal
overflow. `html-validate` and standalone JavaScript parsing exited 0.

PageBin artifact `F19cQq1Q-H_n6T8u9dEbiw` is now revision 2 in the same
`standard` sandbox. `pagebin verify` reported identical local and remote
SHA-256
`389b89e6420bc28ebf834518f7d9308b73a57c257271f83a359b3cc1946cd5b0`.
The capability URL remains in the protected local receipt and was not committed.

No panel implementation, Nix rebuild, activation, service restart, production
shell reload, or live desktop mutation was performed.

## Panel design review completion

The human locked the final recording-history choices: the Recent meetings
work queue shows at most five rows per page; its overflow count opens capped
pages of older actionable jobs; and the recording completion view closes after
five seconds. The completion view also exposes a Copy path action for the
resolved recording path. The short close timer pauses while the pointer or
keyboard focus is inside the completion view so the path and actions remain
usable.

These choices complete the panel design review. The interactive worksheet now
contains zero decision pickers and presents the complete locked contracts for
audio/media, notifications, network/Bluetooth, power/resources, the agent
surface, and recording/meeting workflows. The recording contract preserves
manual retry with the same job identity and incremented attempt, prioritizes
queued, processing, and failed jobs over completed jobs, and treats Obsidian as
the long-term meeting record.

The worksheet now includes an approval-ready implementation outline with eight
bounded lanes: shared controls; audio/media; notifications; network/Bluetooth;
power/resources; agent; recording/meeting; and integration. Each lane states
its work and acceptance boundary. The proposed sequence freezes shared
contracts first, implements and reviews isolated panel lanes, performs full
integration and independent review, and then stops at the deployment gate.
The generated approval prompt authorizes source changes and tests only; it does
not authorize a rebuild, activation, restart, shell reload, live cutover,
legacy cleanup, or soak.

The worksheet's Copy path, Copy approval prompt, and Select text interactions
were exercised successfully. Desktop and 498 px layouts had no page-level
horizontal overflow; the responsive grids collapsed to one column at the
narrow width. `html-validate`, standalone JavaScript parsing, and
`git diff --check` exited 0.

PageBin artifact `F19cQq1Q-H_n6T8u9dEbiw` is revision 3 in the same `standard`
sandbox. `pagebin verify` reported identical local and remote SHA-256
`08e97823d41d849c29537e7d583386176c3f0d9fe7ba8e0022305a0e62518661`.
The stable viewer URL is unchanged, and the capability URL remains in the
protected local receipt rather than the repository.

No panel implementation, Nix rebuild, activation, service restart, production
shell reload, live cutover, cleanup, or soak was performed.

## Panel implementation: production theme v2

Status: reviewed and merged from isolated lane commits
`aafdd39aa863004d1a947ed2e147e18a83044331` and
`103fe00bc7782f702e802e493ded35c68c85f434`. The implementation branch merge
is source-only; the production host loader still rejects schema v2 until its
separate integration pass.

Built:

- Promoted the design-lab v2 contract to `schemas/theme.v2.json` and removed
  the obsolete v1 schema.
- Migrated the canonical Catppuccin Mocha Nix record and Home Manager
  validation to the locked three-level palette, semantic, and component model.
- Locked Noto Sans, JetBrainsMono Nerd Font, Material Symbols Rounded, the
  26-pixel anchored bar metrics, seven-pixel medium radius, 0.80 surface
  opacity, approved color roles, and 66/99/143 ms out-cubic motion tiers.
- Removed `component.osd.background`; OSD surfaces must consume
  `semantic.surface.panel`.
- Made every approved semantic group and role required and rejected all
  unapproved roles.

Verification:

- The orchestrator read the complete cumulative lane diff and the canonical
  theme record before merge.
- `uv run --with jsonschema python
  packages/stillsuit-shell/src/tests/schema-theme/manifest-schema.test.py`,
  exit 0.
- `uvx check-jsonschema --check-metaschema
  packages/stillsuit-shell/schemas/theme.v2.json`, exit 0.
- `git diff --check 7df91376..stillsuit-next-panel-theme`, exit 0.
- The full schema-theme runtime wrapper remains expected-red because
  `src/shell.qml` is still a schema-v1 loader. Its v2 migration is owned by the
  integration pass and must be green before the panel lanes begin.

Review notes:

- The first lane version used generic color maps for the semantic groups. The
  orchestrator rejected it because missing and surplus semantic roles would
  have passed validation.
- A fresh blank-context correction lane froze the exact background, surface,
  content, outline, accent, status, and signal role sets and added negative
  tests for missing and unexpected roles. Its follow-up diff and checks were
  reviewed independently before merge.
- No rebuild, activation, service restart, production-shell reload, Niri
  mutation, legacy cleanup, or soak was performed.

## Panel implementation: power and resources

Status: reviewed and merged from isolated lane commit
`2c5c442b8d2dcb1ba969fa7448f1e39a954a5575`.

Built:

- Added percentage, state, time, profile, health, cycle count, live power draw,
  capacity, and charge-threshold detail to the battery panel.
- Power-profile changes expose pending state, reconcile against daemon truth,
  and visibly return to the authoritative profile after failure.
- Limited resource collection and display to aggregate CPU and physical-memory
  use on a three-second cadence.
- Added an independent one-shot battery watcher with durable deduplication and
  hysteresis, driven by a one-minute user timer with five-second jitter.

Verification:

- The orchestrator reviewed every service, panel, widget, watcher, module, and
  focused test file before merge.
- `packages/stillsuit-shell/src/tests/power-resources/run-fixtures.sh`, exit 0.
- The fixture covers battery parsing and missing data, pending UPower states,
  external profile changes, success, failure rollback, asynchronous completion,
  CPU and memory changes, malformed-sample retention, watcher thresholds,
  deduplication, hysteresis, and the rendered service/timer contract.
- `git diff 2c5c442b8d2dcb1ba969fa7448f1e39a954a5575^..2c5c442b8d2dcb1ba969fa7448f1e39a954a5575 --check`, exit 0.

Review notes:

- The module source is merged but not imported or enabled. Integration must add
  the UPower runtime input and stage removal of legacy compositor-started
  watchers so deployment cannot create duplicate alert owners.
- Focused checks used fake notification and profile owners. No live alert,
  profile mutation, rebuild, activation, service restart, production-shell
  reload, soak, or legacy cleanup was performed.

## Panel implementation: audio and media

Status: reviewed and merged from isolated lane commits
`43ddddb117dedec9b3ffca6959f4a23af1fb3af5` and
`10965757c3f4318b607721eb9bb997b64fda81db`.

Built:

- Kept audio and media in one panel with output-device switching, speaker and
  microphone level and mute controls, no input-device switching, no per-app
  streams, and a hard 100-percent volume ceiling.
- Restored the legacy full-player behavior: active-player preference, explicit
  player selection, metadata and art fallbacks, transport, seek, shuffle, and
  repeat with capability gating.
- Migrated the panel and bar widget to theme v2 and the shared UI contracts.

Verification:

- The orchestrator reviewed the complete audio and media services, production
  panel and widget, manifest, fixture, and follow-up screen correction.
- `packages/stillsuit-shell/src/tests/audio-media/run-fixtures.sh`, exit 0 with
  44 checks.
- The headless Wayland fixture constructs the real panel with host properties
  and proves that its `PanelWindow` receives the injected output screen.
- `git diff 43ddddb117dedec9b3ffca6959f4a23af1fb3af5..10965757c3f4318b607721eb9bb997b64fda81db --check`, exit 0.

Review notes:

- The first implementation omitted the required per-output `screen` property
  and binding. A blank-context correction added the host contract and real-panel
  construction coverage before acceptance.
- Production integration still needs the shared `ui/qmldir` and `pulseaudio`
  runtime input. Those changes belong to the integration step.
- No live PipeWire or MPRIS action, rebuild, activation, service restart,
  production-shell reload, soak, or legacy cleanup was performed.

## Panel implementation: connectivity

Status: reviewed and merged from isolated lane commits
`5738b9a603cd0bf3bc2ec89fbc76ad2382ef58c9` and
`9e83ffcd63412f5ac9937e91d0df1431ba1e005e`.

Built:

- Added a fixed, stdin-driven NetworkManager helper for open, saved, and
  personal secured Wi-Fi. Enterprise and hidden networks hand off to the
  NetworkManager editor.
- MobergAnalytics is the only writable VPN row. Other VPNs appear read-only
  only while active, and Tailscale exposes metadata only.
- Added explicit Bluetooth connected, paired, available, transition, failure,
  battery, and Forget states. A connected Bluetooth audio device is selected
  as the default PipeWire sink after BlueZ reports success.
- Migrated both panels and bar widgets to theme v2 and the shared UI controls.

Verification:

- The orchestrator reviewed the complete helper, Nix wrapper, services, panel
  and widget sources, tests, and the follow-up correction before merge.
- `packages/stillsuit-shell/src/tests/connectivity/run.sh`, exit 0.
- `uvx ruff check` on the helper and helper test, exit 0.
- Both corrected panel files parsed through `qmlformat`, exit 0.
- `git diff 5738b9a603cd0bf3bc2ec89fbc76ad2382ef58c9..9e83ffcd63412f5ac9937e91d0df1431ba1e005e --check`, exit 0.

Review notes:

- The first implementation omitted the required per-output `screen` property
  and binding from both real panels. It also treated a NetworkManager profile
  name as the Wi-Fi SSID, which could misclassify renamed saved profiles. A
  blank-context correction bound both panels and keyed saved profiles by their
  actual `802-11-wireless.ssid`, retaining the UUID and profile name.
- Credentials remain absent from argv and observable service summaries. The
  focused tests used fake owners and commands; no live network, VPN, Bluetooth,
  or audio state changed.
- No rebuild, activation, service restart, production-shell reload, soak, or
  legacy cleanup was performed.

## Panel implementation: notifications

Status: reviewed and merged from isolated lane commits
`735b11445ac4282c270e660e046958c3cd0f9c80` and
`3a6a2ea4e4821f0d6869a1e26b348ff88be84abd`.

Built:

- Added the bounded `9+` unread badge and read-on-open snapshot behavior, so
  notifications present when the center opens become read while later arrivals
  remain unread.
- DND immediately retracts visible banners. Toast dismiss archives, center-row
  removal deletes history, and expired actions become an `Actions expired` note.
- History and persistent popups are both bounded to 24 hours and 100 total
  records. Retention cleanup releases live notification references before
  dismissing the sender object.
- Migrated the notification center, cards, toasts, and bar widget to theme v2
  and the shared UI contracts.

Verification:

- The orchestrator reviewed the full notification model, policy, service,
  views, tests, and the follow-up retention correction before merge.
- `packages/stillsuit-shell/src/tests/notifications/run-fixtures.sh`, exit 0.
- `packages/stillsuit-shell/src/tests/notifications/run-view-fixture.sh`, exit 0.
- `packages/stillsuit-shell/src/tests/notifications/run-shadow-fixture.sh`, exit 0.
- `git diff --check 735b11445ac4282c270e660e046958c3cd0f9c80..3a6a2ea4e4821f0d6869a1e26b348ff88be84abd`, exit 0.

Review notes:

- The first reviewed implementation applied the 24-hour bound only to archived
  history, allowing deadline-zero popups to survive indefinitely. A fresh
  blank-context correction added restart and runtime popup pruning plus live-ref
  cleanup tests before the lane was accepted.
- No live notification was sent outside the fixture's private D-Bus. No rebuild,
  activation, service restart, production-shell reload, soak, or legacy cleanup
  was performed.

## Panel implementation: theme-v2 host integration

Status: integrated by the orchestrator in commit
`2f3d46c9a2dad295b53c63dfb6f633a29619bbec` after both Phase A lane merges.

Built:

- Migrated the host loader from the v1 groups to the v2 semantic, component,
  typography, metrics, motion, and effects groups.
- Added a palette-free public theme view. Both plugin contexts and the public
  theme IPC omit the raw palette while retaining the approved resolver output.
- Removed the obsolete v1 runtime fixture and generated the canonical v2
  fixture from the Nix theme record.
- Updated the host contract, design language, and design-lab documentation to
  point at the production v2 schema without implying deployment.

Verification:

- `bash packages/stillsuit-shell/src/tests/ui/run-fixtures.sh`, exit 0 with 49
  checks.
- `bash packages/stillsuit-shell/src/tests/schema-theme/run.sh`, exit 0,
  including accepted and rejected runtime theme cases.
- `bash packages/stillsuit-shell/src/tests/run-lane-b-fixtures.sh`, exit 0 with
  69 core and 24 repair checks.
- `bash -n` on all three runners and `git diff --check`, exit 0.
- The host fixtures assert that `stillsuit theme` and an independently created
  plugin context omit `palette` while retaining semantic and component roles.

No panel workflow was changed. No rebuild, activation, service restart,
production-shell reload, Niri mutation, legacy cleanup, or soak was performed.

## Panel implementation: agent surface

Status: reviewed and merged from isolated lane commit
`cf32cf9607f606187d0b9c57ba975ac1337139bd`.

Built:

- Removed the agent bar-widget contribution and source. The plugin now exposes
  only its global fixed-action service.
- Preserved the Mod+Grave IPC route, exact `=stillsuit-agent` tmux identity,
  external Ghostty surface, helper safety, and source-only warm-reopen work.
- Staged the approved 72% to 60% width and height change as
  `docs/plans/stillsuit-agent-geometry.patch`; the live Niri configuration was
  not edited.

Verification:

- The orchestrator read the complete five-file diff before merge.
- `packages/stillsuit-shell/src/plugins/builtin/agent-panel/tests/run.sh`, exit
  0, including the service-only manifest and absent-widget assertions.
- `git apply --check docs/plans/stillsuit-agent-geometry.patch`, exit 0.
- The patch was applied to an archived disposable copy of the current Niri
  configuration and `niri validate --config` exited 0.
- `git diff --check dd9ea414..stillsuit-next-panel-agent`, exit 0.

The staged geometry patch and warm reopen remain part of a later human-approved
deployment. No live IPC, window/process action, rebuild, activation, service
restart, production-shell reload, live Niri edit, soak, or legacy cleanup was
performed.

## Panel implementation: bar, workspaces, clock, and OSDs

Status: reviewed and merged from isolated lane commits
`40674c9be87699eb9544e0e17033326f046df3cd` and
`af22a8208622856557be63bcd93609b28698f14d`.

Built:

- Migrated the per-output bar, inline workspace and Niri-column treatment,
  clock, and OSD views to theme v2 and the shared UI contracts.
- Locked a 26-pixel full-width top bar, zero outer gap, 26-pixel exclusion
  zone, and square anchored corners.
- Kept one global OSD service with per-output views. Audio, brightness, and
  dictation use their semantic signal roles; error uses semantic danger.
- OSD surfaces use `semantic.surface.panel`, the medium radius, and the OSD
  border, track, fill, and text assignments.
- Added a deterministic two-output headless fixture under `src/tests/bar-v2`.

Verification:

- The orchestrator read every production file, the source contract, runner,
  and full headless fixture before merge.
- `packages/stillsuit-shell/src/tests/bar-v2/run.sh`, exit 0 after correction.
- The fixture proves distinct output IDs and workspace rows, one clock service,
  one OSD service with two views, inline workspace/column layout, accessibility
  hooks, signal mapping, and reduced motion.
- The lane's d1 static, schema/theme, shared UI, d5 workflow, Node syntax, and
  diff checks exited 0.

Review notes:

- The first reviewed bar inherited `radiusMedium` from `ShellSurface`, which
  contradicted the approved anchored treatment and left transparent corner
  cutouts. A fresh blank-context correction set the anchored production bar
  radius to zero and added a rejecting source assertion.
- Existing d1 QML and d4 harnesses flatten plugin directories and therefore do
  not preserve the new shared `ui/` import. The d1 static fixture also retains
  an obsolete 40-pixel exclusion assertion. These are integration-owned test
  harness updates, not accepted lane failures, and remain required before full
  verification.
- No rebuild, activation, service restart, production-shell reload, compositor
  mutation, soak, or legacy cleanup was performed.

## Panel implementation: shared UI contracts

Status: reviewed and merged from isolated lane commit
`b920a771f4460a59e9ee8be735594f7c09cf2795`.

Built:

- Added one guarded activation primitive shared by buttons, owner-controlled
  toggles, rows, and bar clusters. Pointer, Enter, Return, and Space use the
  same path; disabled and busy controls do not dispatch.
- Added reusable row, section-label, status, centered state, and busy-indicator
  components and migrated the existing text, icon, surface, slider, button,
  toggle, bar-cluster, panel, and cursor primitives to the approved v2 roles.
- Kept selected and danger surfaces borderless, fixed row icon-column
  alignment, bounded sliders to their declared range, and made reduced motion
  resolve transitions immediately without animating layout measurements.
- Documented the public component APIs and the owner-controlled toggle model.

Verification:

- The orchestrator read all component implementations, the complete fixture,
  the runner, and the cumulative lane diff before merge.
- `bash packages/stillsuit-shell/src/tests/ui/run-fixtures.sh`, exit 0 with 49
  checks.
- The lane's `run-lane-b-fixtures.sh`, exit 0 with 67 core and 24 repair
  checks.
- `git diff --check 7df91376..stillsuit-next-panel-shared`, exit 0.

Review notes:

- Quickshell 0.3 lacks the newer full accessibility attached API. The shared
  controls expose a stable `accessibleName` contract and readable labeled or
  icon-derived fallbacks; panel callers must supply a more specific name when
  an icon alone is ambiguous.
- Panel lanes remain responsible for passing reduced-motion state and for
  using specific accessible names at each call site.
- No rebuild, activation, service restart, production-shell reload, Niri
  mutation, legacy cleanup, or soak was performed.
