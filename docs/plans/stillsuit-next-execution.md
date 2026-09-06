# Stillsuit Next — orchestrated migration handoff

You are the orchestrator for a one-night, multi-agent migration of the Stillsuit
Quickshell desktop shell to a plugin-host architecture adapted from Omarchy
Quattro. You plan, freeze contracts, delegate lane work to subagents, review
their diffs, merge, verify, and stop at "branch ready for human review."

## Ground truth

| What | Where |
|---|---|
| Repo / branch | `/home/kabilan/dotfiles`, branch `stillsuit-next` (already checked out) |
| Current shell source | `home/desktop/wayland/quickshell/stillsuit/` (~38 QML files, works today on Quickshell 0.3.0) |
| Current shell Nix wiring | `home/desktop/wayland/quickshell/default.nix` |
| Upstream reference (READ-ONLY, never modify, never depend on at runtime) | `/vault/repos/omarchy-quattro` — basecamp/omarchy tag v4.0.0, commit `f0020448ca87329199de7cb12f2015ebc4a3e5e7`, MIT. Shell in `shell/`, agent launcher in `bin/omarchy-agent` |
| Architecture plan (authoritative design doc) | https://page-bin.com/raw/8YYV7NVkOygV1RI1PBaWZQ/44JO7cS_JGAJ82BGEnY3rj2IQe5Uhwzg96DrgHJwOdw (v5). Read it fully before starting. |
| Quickshell compat spike result | `docs/plans/quickshell-compat-note.md` (verdict: OK-with-workarounds) |
| Target machine | Jacurutu, NixOS + Home Manager flake at repo root, compositor Niri, Quickshell 0.3.0 from nixpkgs |

Spike findings you must design around (details and citations in the compat
note — read it before Phase 0):

- **Async kill.** 0.3.0's `quickshell kill` returns before the instance exits
  (Quattro requires quickshell-git for synchronous kill). Never assume
  synchronous kill. Whole-shell replacement goes through the systemd user unit
  (ordered stop→start) or an explicit bounded wait for the old PID to exit and
  the D-Bus name to be released — never a fixed sleep. Keep an IPC readiness
  ping as a second barrier after process start (live PID ≠ ready registry).
- **Everything else is API-compatible.** All Quickshell modules, loaders,
  Process/FileView, IpcHandler, Variants/PanelWindow/PopupWindow patterns
  Quattro uses exist in 0.3.0. `Loader.errorString()` is non-portable — don't
  depend on it; use `Qt.createComponent` when compile diagnostics matter.
- **HostContext must inject resolved config/data/state roots.** Quattro's
  plugins mix HOME/XDG/OMARCHY_PATH conventions; store-backed plugins must not
  inherit that. One convention, injected.
- **Keep the QQmlComponent alive for every registered widget** and make
  dynamic construction async-capable (entry point may be `Loading` on the
  initiating call).
- **Config identity ≠ instance identity.** One canonical config path/name;
  generated instanceId for diagnostics only; never "newest instance" as a
  correctness mechanism once systemd guarantees a single instance.
- **Per-output scope belongs in the manifest.** Services/registries are
  global; `Variants` creates per-output views. Never instantiate a service per
  screen.
- **Plugins never get whole-shell kill.** IPC exposes unload/reload/rescan;
  systemd owns process replacement.

## Strategic decisions already made (do not relitigate)

1. **Direct migration, no legacy backend.** No `src/legacy/`, no per-provider
   legacy switches, no dual-backend option. Rollback story is the git branch
   plus Home Manager generations. The new shell replaces the old in one cutover
   (Gate 2), which happens AFTER human review — never tonight.
2. **Shadow mode during development.** All runtime testing uses a separate
   Quickshell config ID and temporary HOME/XDG dirs. Development shells never
   claim the production bar exclusive zone, the `org.freedesktop.Notifications`
   D-Bus name, the recorder, meeting worker, lock, or polkit.
3. **Trust boundary is the dotfiles repo.** No runtime plugin install, no
   marketplace, no sandbox. Keep manifest validation, load-error containment,
   and fallback because trusted generated QML can still be buggy.
4. **Copy/adapt/reject ledger from the plan (section 10) is binding.** Notably
   reject: `bash -lc` action APIs, executable notification hints, whole-file
   config rewriting by the shell, Hyprland/UWSM assumptions, runtime Git.
5. **Theme**: one curated Catppuccin Mocha record is canonical; generate the
   Stillsuit JSON contract plus a lossy base16 projection for existing Stylix
   consumers. Selection is rebuild-time. Never round-trip base16 back into the
   canonical record.
6. **Agent panel model is runtime-editable.** The panel helper command shape is
   Nix-fixed, but model / reasoning-effort / service-tier are read from a small
   runtime config file (e.g. `~/.config/stillsuit/agent-panel.json`) with
   Nix-provided defaults, so changing the model does NOT require a rebuild. IPC
   still cannot alter the command — only the config file edit can.
7. **MIT provenance**: any copied or substantially-derived upstream code gets a
   file-level attribution header and an entry in
   `docs/attribution/omarchy-quattro.md`, and the MIT notice is retained.

## Hard rules for you and every subagent

- **No activation.** Never run `nixos-rebuild`, `home-manager switch`, enable a
  systemd unit, restart the live shell, or kill any live process (Stillsuit,
  Waybar, Niri, the notification daemon). Build and evaluate only.
- **Never edit live-linked files' effect.** The Niri `config.kdl` and the
  running shell read out-of-store working-tree files. All changes stay staged
  on the branch; workers operate in git worktrees, never in the main checkout.
- **Worktrees per lane.** Create one git worktree per lane under
  `.claude/worktrees/` or `/tmp/stillsuit-lanes/` from branch `stillsuit-next`,
  each on its own branch (`stillsuit-next-lane-a` etc). You (orchestrator) own
  the main checkout and do all merging there.
- **Exclusive paths.** Each lane touches only its assigned paths (below). If a
  worker needs a shared file changed, it reports the needed change to you and
  you make it in the main checkout.
- **Verification discipline.** Never pipe test/build/lint commands through
  filters that mask exit codes. Pattern: `cmd > /tmp/out 2>&1; echo "exit=$?"`.
- **D-Bus isolation.** All notification tests run under `dbus-run-session`.
  A test that touches the live session bus's `org.freedesktop.Notifications`
  is a bug in the test.
- **Wayland surfaces.** Isolated Quickshell runs still connect to the live
  Wayland session and may briefly render surfaces. Acceptable for short fixture
  runs; keep them short, never claim exclusive zones, and always tear down.
- **Subagents, not tmux.** Delegate lane work to your subagents with
  blank/forked context. Every subagent prompt must be fully self-contained:
  worktree path, upstream path, contract file paths, exclusive paths, the hard
  rules above, acceptance criteria, and "end with a summary of changed files."
  Do not use fast mode; use medium reasoning effort for mechanical lanes and
  high for Lane B, Lane E, and any diff review you delegate.
- **Evidence ledger.** Maintain `docs/plans/stillsuit-next-evidence.md`: per
  lane — what was built, verification commands run with exit codes, fixtures
  passing, open issues, review notes. Update it at every merge.
- **Review before merge.** Read every lane's diff yourself before merging. If a
  lane's output misses the bar, send corrections back to a fresh subagent with
  the specific defects listed; don't merge and hope.

## Phase 0 — Contract freeze (do this yourself, first, no subagents)

Produce one commit on `stillsuit-next` containing:

1. `packages/stillsuit-shell/schemas/manifest.v1.json` — JSON Schema for plugin
   manifests: `schemaVersion`, `id` (reverse-dns, `stillsuit.*`), `name`,
   `version`, `apiVersion` (host compatibility, actually enforced), `kinds`
   (enum: `bar`, `bar-widget`, `service`, `panel`, `overlay`, `menu`; unknown
   kinds are rejected), `entryPoints` (per kind, relative paths), optional
   `capabilities` (documentation of authority, not sandboxing), optional
   `dependencies` (other plugin ids), optional per-kind config blocks
   (`barWidget.defaultSection`, `barWidget.allowMultiple`, `keepLoaded`),
   optional `stateSchemaVersion`.
2. `packages/stillsuit-shell/schemas/theme.v1.json` — the curated theme record
   from plan section 04: identity, palette (neutral ramp + chromatic),
   semantic colors (surface/text/border/status), controls, typography,
   geometry, motion. All colors `#rrggbb`.
3. `packages/stillsuit-shell/docs/host-contract.md` — HostContext v1: the exact
   injected context object (`theme`, `compositor`, `services`, `panels`,
   `logger`, `settings`, `actions`, `instanceId`), the surface lifecycle state
   machine (`unloaded → loading → loaded → error`; queued open payloads are
   cleared on hide/disable/error/reload), the typed IPC action list (surface
   open/close/toggle by id, shell status/ping, theme query, agent-panel
   open/hide/toggle/status/terminate), fallback semantics (broken bar plugin →
   builtin bar; broken widget releases its claim), and the restart rule from
   the spike (no synchronous-kill assumption).
4. `docs/plans/stillsuit-next-lanes.md` — the lane/path ownership map (copy
   from below, adjusted if you must).

Design these by reading the plan and the upstream implementations
(`shell/plugins/PluginRegistry.qml`, `shell/shell.qml`) — steal the shape,
enforce what upstream doesn't. Keep them small; v1 is a floor, not a cathedral.

## Lanes

Dependency order: `Phase 0 → {A, C, E, F} in parallel, B in parallel → D
(needs B compiling) → integration`. Lane D is internally parallel (D1–D5) once
B lands; you may fan out multiple D subagents.

### Lane A — Nix module, package, theme generation (medium effort)
**Owns:** `modules/home/stillsuit/**`, `packages/stillsuit-shell/default.nix`,
`packages/stillsuit-shell/themes/**`, `docs/attribution/omarchy-quattro.md`.
**Build:** typed Home Manager module (`programs.stillsuitShell`): options.nix,
assertions.nix (exactly one bar owner, exactly one notification owner, plugin
id/path validation against manifest schema), theme.nix (Catppuccin Mocha record
→ generated Stillsuit theme JSON + base16 projection wired to existing Stylix
consumers), registry.nix (deterministic manifest catalog from store paths),
service.nix (systemd user unit, `graphical-session.target`, restart policy,
default-off), package with exact runtime PATH (every helper binary pinned).
Also `development.sourceMode = "store" | "local"` for the out-of-store dev
loop. **Proof:** `nixfmt --check`; `nix flake check --no-build`; evaluation of
the Jacurutu closure; `nix build --no-link` of the package. No activation.

### Lane B — Host core + interaction primitives (high effort)
**Owns:** `packages/stillsuit-shell/src/{shell.qml,core/**,ui/**,tests/**}`.
**Build:** intentionally small `shell.qml` composition root;
`core/HostContext.qml`, `core/PluginCatalog.qml` (scan + validate against
manifest schema, reject unknown kinds, containment: one bad manifest/component
omits only that plugin), `core/ServiceRegistry.qml` (one instance per service,
injected — never per-import singletons), `core/SurfaceRouter.qml` (lazy
loaders, lifecycle states, `keepLoaded`, queued-payload clearing, focused-output
routing), `core/IpcFacade.qml` (typed actions only). Port the interaction kit
from upstream (`shell/Ui/Panel.qml:5–57`, `PanelKeyCatcher.qml:33–84`,
`PointerMoveGate.qml:8–53`, `CursorSurface.qml:4–40`) into Stillsuit-styled
`ui/` primitives with attribution. **Proof:** headless boot under temp XDG with
a separate config ID; fixture plugins (valid, malformed manifest, broken QML,
unknown kind) produce correct catalog/error states; broken-bar fallback works;
repeated reload leaves one process and one IPC owner.

### Lane C — Agent quake panel (medium effort)
**Owns:** `packages/stillsuit-shell/src/plugins/builtin/agent-panel/**`,
`packages/stillsuit-shell/bin/stillsuit-agent-panel` (or equivalent helper),
its Nix wiring inside a clearly-marked block Lane A exposes, staged Niri
snippets under `docs/plans/staged-niri-changes.md` (NOT applied to config.kdl).
**Build:** Nix-built helper managing one named tmux session
(`stillsuit-agent`) running codex (`codex --yolo --model <model> --config
model_reasoning_effort=<effort> --config service_tier=<tier>`); model/effort/
tier read at launch from `~/.config/stillsuit/agent-panel.json` (Nix-generated
defaults file if absent; no rebuild needed to change model); Ghostty window
with app ID `io.stillsuit.AgentPanel`; actions limited to
open/hide/toggle/status + separate terminate; serialized with a lock; hide
closes only the Ghostty window, tmux persists. Plugin: manifest + bar widget +
service wrapping the helper. **Proof:** scripted toggle storm leaves exactly
one tmux session and ≤1 Ghostty window; hostile IPC payloads cannot alter
argv; helper works with tmux absent-session, stale-window, and dead-codex
states.

### Lane E — Notification engine (high effort)
**Owns:** `packages/stillsuit-shell/src/services/Notification*`,
`src/plugins/builtin/notifications/**`, notification fixtures under
`src/tests/`.
**Build:** port the existing Stillsuit notification daemon
(`home/desktop/wayland/quickshell/stillsuit/` — find the current center/daemon
QML) into the Service (D-Bus owner, live refs, timers, action dispatch) /
Model (plain snapshots, replacement keys, bounded history, corrupt-record
isolation) / Policy (DND, urgency, retention, multi-output presentation) /
View (center, toast) split. Preserve Stillsuit's named-action UI, direct
action invocation, DND policy, and center. Borrow Quattro's snapshot/
replacement/expiry lifecycle (archive snapshot then `expire()`; restart
deadline on replacement). Any executable hint (`omarchy-exec` or otherwise) is
inert data, asserted by fixture. **Proof (all under `dbus-run-session`):**
requested timeouts, replacement-only changes, all named/default actions, DND
classes, 100-notification burst, malformed history recovery, forged exec hint
inert before and after restart. Never touches the live session bus.

### Lane F — Agent-workspace removal (medium effort, fully independent)
**Owns:** the removal inventory only: `bin/agent-workspace-pin`, its
package/service Nix (`home/desktop/wayland/niri/default.nix` workspace parts),
workspace + `acu.*` window rules and Mod+0 binds in the staged Niri material,
TopBar agent-workspace styling in stillsuit QML, `niri-computer-use` skill's
`spawn --bg` behavior + doctor check + recipes
(`agents/skills/niri-computer-use/`).
**Build:** remove the feature coherently on the lane branch; keep ordinary and
waited computer-use launches working; stage `config.kdl` edits as a patch or
clearly-separated commit (the live file is symlinked — the working-tree edit is
acceptable ONLY if Niri does not hot-reload it; verify first, otherwise stage
as a `.patch` in `docs/plans/`). **Proof:** `rg` over the repo finds zero
remaining references to the workspace/pin/`acu --bg` contract; `niri validate`
against the staged config passes; skill docs updated.

### Lane D — Desktop port (after B compiles; fan out D1–D5, medium effort each)
**Owns:** `packages/stillsuit-shell/src/{services/**,plugins/builtin/**}`
except agent-panel and notifications.
- **D1** bar: wrap current TopBar as the builtin fallback `bar` plugin with
  manifest-backed widget slots; per-output instances; one exclusion-zone owner.
- **D2** compositor: promote NiriState into `services/NiriService.qml` behind
  a compositor-adapter interface (event stream + reconciliation preserved).
- **D3** services split: audio/network/power/battery/bluetooth — one shared
  service instance each, views consume via context; package helper argv.
- **D4** widgets/panels: clock, workspaces, resources, meeting, recording
  widgets into bar slots; their popout panels through SurfaceRouter with
  mutual exclusion and focused-output placement.
- **D5** OSD: volume/brightness/Dictator-waveform as one keep-loaded overlay
  plugin preserving current stacking and the live waveform; recording/meeting
  state exposed as a shared service (contracts versioned BEFORE views move;
  prove a shell restart cannot kill an active recording — fixture the state
  files, do not touch the live recorder).
**Rule for all of D:** per-output views never multiply services, timers,
sockets, or IPC names. **Proof:** shadow-mode preview under separate config ID
renders bar + panels; fixture matrix; screenshot checklist vs current desktop
(screenshots of the preview only — never restart the live shell).

## Integration and verification ladder

After each lane merge, run in the main checkout:
1. Static: manifest/schema validation over all builtin plugins; duplicate
   id/IPC checks; `rg` for stale agent-workspace refs; provenance headers
   present on ported files.
2. Nix: `nixfmt --check`, `nix flake check --no-build`, Jacurutu closure
   evaluation, final `nix build --no-link`.
3. Isolated runtime: headless host boot + fixture suite + notification suite
   under `dbus-run-session`.
4. Niri: `niri validate` against staged config material.
Record everything (with exit codes) in the evidence ledger.

## Gates (human-owned; you stop before them)

- **Gate 1 (small, maybe tonight, human decides):** apply workspace removal +
  Waybar disable to the current desktop as its own generation. You only
  prepare the exact commands and rollback note in the evidence ledger.
- **Gate 2 (NOT tonight):** shell cutover — Niri stops direct-starting the old
  shell, systemd unit starts the new one, notification name moves with it.
  You prepare the ordered handoff script (stop → wait for PID exit + D-Bus
  name release → start → verify acquisition) and its rollback, but never run
  it.

## Stop condition

Stop when: lanes merged as far as dependencies allow, verification ladder
green for everything merged, evidence ledger current, remaining work itemized
at the bottom of the ledger with per-item next steps. Leave the branch clean
(no uncommitted debris, worktrees pruned or listed in the ledger). Do not
notify, do not activate, do not push. The human reviews the branch next.
