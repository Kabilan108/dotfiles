# Architecture decision records

These records hold the non-obvious decisions that used to live in code comments: why a setting has its value, which upstream bug a workaround covers, and when it can go. The repository no longer allows code comments (see [0001](0001-ban-code-comments.md)), so the reason for a choice goes here or in a doc under `docs/`.

## Adding an ADR

Take the next free number and name the file `NNNN-<slug>.md`. Use this template:

```markdown
# Sentence-case title that states the decision

Status: Accepted.

## Context

## Decision

## Consequences

## Where
```

"Where" lists repo paths that exist, with symbol or setting names in parentheses and no line numbers. The converted records add "Recorded from code comments on 2026-11-20." to the status line; new ones leave it off. Add a row to the index below. When a change needs explaining, write the reason in an ADR or a doc, not in a comment.

## Index

| Number | Title | Area |
| --- | --- | --- |
| [0001](0001-ban-code-comments.md) | Ban code comments; record decisions as ADRs | repo |
| [0002](0002-fleet-ssh-access-and-host-keys.md) | lib/fleet.nix drives SSH access, and SSH clients pin identities and host keys per purpose | fleet/hosts |
| [0003](0003-tailnet-policy-grants.md) | Tailnet grants follow each device's trust level | fleet/hosts |
| [0004](0004-sietch-hardware-and-resources.md) | sietch keeps Wi-Fi off, uses the CUDA cache and caps agent VMs | fleet/hosts |
| [0005](0005-sietch-tailscale-operators.md) | Agents on sietch need sudo to change the main Tailscale client | fleet/hosts |
| [0006](0006-tleilax-credential-box.md) | tleilax is a credential box that agents and sietch cannot reach | fleet/hosts |
| [0007](0007-tleilax-boot-and-unlock.md) | tleilax boots from a LUKS2 Adiantum USB SSD and unlocks over SSH in the initrd | fleet/hosts |
| [0008](0008-tleilax-executor-v2.md) | Executor v2 runs in Podman on tleilax with its keys outside the data volume and UID-scoped egress | fleet/hosts |
| [0009](0009-tleilax-failed-unit-alerts.md) | Every failed unit on tleilax sends one Hark alert per hour | fleet/hosts |
| [0010](0010-agenix-recovery-recipients.md) | Secrets used on one host keep a second recipient for recovery | fleet/hosts |
| [0011](0011-nix-access-tokens.md) | Nix access tokens reach root and user Nix through links to agenix files | fleet/hosts |
| [0012](0012-onepassword-for-agents.md) | Agents use 1Password through a per-host service account that agent-op keeps out of transcripts | fleet/hosts |
| [0013](0013-flake-input-build-sources.md) | Flake inputs follow nixpkgs unless a binary cache match matters more, and niri builds against our nixpkgs | fleet/hosts |
| [0014](0014-temporary-upstream-workarounds.md) | Temporary pins and backports carry their own removal condition | fleet/hosts |
| [0015](0015-prebuilt-app-packaging.md) | Prebuilt vendor apps are extracted and verified, never patched | fleet/hosts |
| [0016](0016-peripheral-quirks.md) | Audio and input devices get targeted fixes for observed misbehaviour | fleet/hosts |
| [0017](0017-nvidia-niri-free-buffer-pool.md) | niri gets NVIDIA's free buffer pool limit | nixos modules |
| [0018](0018-libvirt-and-kvm-access.md) | System libvirt asks for an admin password per connection, and /dev/kvm is limited to the kvm group | nixos modules |
| [0019](0019-repos-bind-mount.md) | ~/repos is a bind mount of /vault/repos | nixos modules |
| [0020](0020-system-docker-storage-and-config-ownership.md) | System Docker refuses a replaceable data root, and kabilan owns ~/.config/moberg | nixos modules |
| [0021](0021-teamviewer-daemon-on-demand.md) | TeamViewer's root daemon does not start at boot | nixos modules |
| [0022](0022-deploy-signers-and-push.md) | Deploy tags are signed with a verify-required YubiKey key file and pushed as a deploy key | deploy |
| [0023](0023-deploy-tag-format-and-verification.md) | Deploy tags are accepted only in one strict, fully signed format | deploy |
| [0024](0024-deploy-trigger-socket-broker.md) | Receivers start deploys through a root broker socket and record each run by job ID | deploy |
| [0025](0025-deploy-receiver-root-isolation.md) | The deploy receiver runs root Nix and git on store files and root-owned paths only | deploy |
| [0026](0026-backup-host-key-bootstrap.md) | Hosts with a NAS get a root-only SSH host key before backups run | backup |
| [0027](0027-backup-job-guards-and-retries.md) | Backup jobs fail fast, count their own retries and are watched from another host | backup |
| [0028](0028-backup-vm-test-fixtures.md) | Backup VM test fixtures force each alert and failure path | backup |
| [0029](0029-jacurutu-backup-scope.md) | jacurutu backs up authored work and skips data that can be fetched again | backup |
| [0030](0030-blocky-doh-only-and-private.md) | Blocky publishes only DoH and plain tailnet DNS, and keeps no record of queries | selfhost |
| [0031](0031-cpa-fronts-and-clients.md) | CPA reaches the tailnet only through loopback fronts, and clients use a tailnet-only shared key | selfhost |
| [0032](0032-cliproxyapi-sandbox-and-config-rules.md) | The CPA unit runs sandboxed, and preStart enforces logging and request rules | selfhost |
| [0033](0033-cpa-test-harness.md) | CPA tests account for CPA, nginx and dashboard behavior | selfhost |
| [0034](0034-hark-state-and-release-material.md) | Hark's server state, published APKs and release secrets have separate paths and owners | selfhost |
| [0035](0035-media-library-mounts.md) | The media library mounts over SMB with 1 MiB seal buffers, and Jellyfin waits for it | selfhost |
| [0036](0036-siren-environment-and-model-cache.md) | Siren shares the model cache anonymously, trusts the system CA store and boosts measured vocabulary | selfhost |
| [0037](0037-shared-shell-base.md) | Every fleet host shares one shell base, with store copies on tleilax | home |
| [0038](0038-user-shell-environment.md) | The user environment pins CA trust, keeps credentials out of shared caches and turns off Atuin for Teams | home |
| [0039](0039-bash-session-startup.md) | Route interactive Bash sessions to tmux over SSH and niri on tty1 | home |
| [0040](0040-agy-ssh-keyring.md) | Hide SSH variables from agy when a local session bus exists | home |
| [0041](0041-antigravity-config-sync.md) | Antigravity settings are merged in place and bridged into T3 profiles | home |
| [0042](0042-t3-code-server-and-client.md) | Home Manager owns the T3 Code server on sietch; jacurutu runs only the client | home |
| [0043](0043-viewh5-follows-git-head.md) | viewh5 installs from Git HEAD without a release-age hold | home |
| [0044](0044-desktop-integration-quirks.md) | Desktop configuration works around GLib, XDG, libadwaita and AppImage quirks, and file dialogs open in scout | desktop |
| [0045](0045-niri-home-module.md) | Link a hand-written niri config and install agent computer-use tools | desktop |
| [0046](0046-sietch-niri-output.md) | Pin sietch's ultrawide to 180 Hz with a max-bpc fallback | desktop |
| [0047](0047-lock-screen-releases-dictator-mic.md) | Release Dictator's microphone while the screen is locked | desktop |
| [0048](0048-stillsuit-replaces-tray-applets.md) | Hide nm-applet and blueman tray applets under Stillsuit | desktop |
| [0049](0049-nvim-markdown-oxide-vault-scope.md) | Scope markdown-oxide to the vault and fill its client gaps | desktop |
| [0050](0050-nvim-note-templates.md) | Render note templates by substitution and create notes exclusively | desktop |
| [0051](0051-nvim-vault-markdown-links.md) | Vault link tools skip code examples and follow markdown-oxide's ID rules | desktop |
| [0052](0052-nvim-vault-prose-layout.md) | Edit vault notes as soft-wrapped prose at a capped width | desktop |
| [0053](0053-nvim-vault-task-conventions.md) | Mirror the vault's task conventions in Neovim | desktop |
| [0054](0054-stillsuit-helper-paths.md) | Stillsuit helpers run on an exact, declared PATH and get absolute tool paths | stillsuit core |
| [0055](0055-shell-logs-in-journal.md) | Stillsuit shell logs go to the bounded user journal | stillsuit core |
| [0056](0056-theme-base16-projection.md) | Stillsuit derives a one-way Base16 projection for Stylix | stillsuit core |
| [0057](0057-quickshell-binding-workarounds.md) | Stillsuit works around Quickshell 0.3 binding behaviours and pins them with fixtures | stillsuit core |
| [0058](0058-catalog-revision-churn.md) | Catalog and registry suppress redundant revisions and refreshes | stillsuit core |
| [0059](0059-plugin-watcher-rescan.md) | Plugin watcher keys rescans on every scan input, including rejected symlinks | stillsuit core |
| [0060](0060-panel-and-menu-hosts.md) | Panel and menu hosts own geometry, input masks and teardown order | stillsuit core |
| [0061](0061-icon-resolution-cache.md) | Icon tinting and theme checks are cached per QML engine | stillsuit core |
| [0062](0062-niri-event-stream.md) | Niri state comes from the event stream, with reconciliation as backstop | stillsuit core |
| [0063](0063-network-service-backend.md) | Network service limits the Quickshell scanner and falls back to helper polling | stillsuit core |
| [0064](0064-notification-lifecycle.md) | Notification rows follow a fixed lifecycle across hover, quiet mode and restarts | stillsuit core |
| [0065](0065-notification-sender-normalization.md) | Notifications normalize sender identity before presentation | stillsuit core |
| [0066](0066-helper-backed-services.md) | Helper-backed services leave external state to their workers | stillsuit core |
| [0067](0067-agent-panel-helper.md) | Agent panel helper works around Ghostty and tmux process quirks | stillsuit core |
| [0068](0068-agy-usage-probe.md) | The agy usage probe ignores transient sign-in noise and pins its update flag | stillsuit core |
| [0069](0069-clipboard-collector-hardening.md) | Clipboard collector treats its inputs as hostile and dies with its parent | stillsuit core |
| [0070](0070-workbench-fixture-seams.md) | Workbench fixtures adapt to the real session through narrow seams | stillsuit core |
| [0071](0071-bar-slot-model-and-press-routing.md) | Bar keeps widget slots stable and routes presses around widgets | stillsuit plugins |
| [0072](0072-clipboard-expiry-timing-and-clock-skew.md) | Clipboard expiry batches wakes and clamps future timestamps | stillsuit plugins |
| [0073](0073-clipboard-history-writes-are-read-back.md) | Clipboard history writes are verified by reading them back | stillsuit plugins |
| [0074](0074-dev-checkouts-plugin.md) | The dev-checkouts plugin ships disabled and reaches sietch through a forced-command key | stillsuit plugins |
| [0075](0075-dictation-panel-meter-and-history-refresh.md) | Dictation panel meters only when open and refreshes history after idle | stillsuit plugins |
| [0076](0076-launcher-engine-returns-validated-intents.md) | Launcher engine is injected with its modules and returns validated intents | stillsuit plugins |
| [0077](0077-launcher-matcher.md) | Launcher matcher ports fzf FuzzyMatchV2, prunes by score ceilings and is tested for parity | stillsuit plugins |
| [0078](0078-launcher-ranking-and-result-order.md) | Launcher ranks rows with a quickselect cut and keeps provider order for strong matches | stillsuit plugins |
| [0079](0079-launcher-usage-boost-follows-elephant.md) | Launcher usage boost follows Elephant's formula | stillsuit plugins |
| [0080](0080-launcher-qalc-and-fd-lookups.md) | Launcher gates and shapes its qalc and fd lookups | stillsuit plugins |
| [0081](0081-launcher-web-url-detection.md) | Launcher web provider detects URLs narrowly | stillsuit plugins |
| [0082](0082-launcher-current-window.md) | Launcher names the window focused before it opened, not niri's focus flags | stillsuit plugins |
| [0083](0083-launcher-menu-sizing-and-pointer-gate.md) | Launcher menu narrows short lists and ignores a resting pointer | stillsuit plugins |
| [0084](0084-launcher-work-runs-only-while-open.md) | Launcher work runs only while the menu is open | stillsuit plugins |
| [0085](0085-notifications-spring-motion-and-presence.md) | Notification toasts move on closed-form springs and keep leaving cards in place | stillsuit plugins |
| [0086](0086-recording-panel-and-microphone-meter.md) | Recording panel and microphone meter | stillsuit plugins |
| [0087](0087-resources-collector-measurement-rules.md) | Resources collector measures physical devices and leaves unknowns absent | stillsuit plugins |
| [0088](0088-tray-menu-and-window-matching.md) | Tray renders DBusMenus in-shell and ties items to their windows | stillsuit plugins |
| [0089](0089-stillsuit-fixture-harness.md) | Stillsuit runtime fixtures isolate from the live session and wait out Qt asynchrony | stillsuit tests |
| [0090](0090-clipboard-browser-offers-and-attribution.md) | Clipboard handling follows the 2026-10-05 probe of browser offers and skips copies it cannot attribute | stillsuit tests |
| [0091](0091-clipboard-fixture-failure-paths.md) | Clipboard fixtures run real collector paths under the service PATH and forced write failures | stillsuit tests |
| [0092](0092-clipboard-test-text-gate-timing.md) | Clipboard tests set the text gate and read delays around fake wl-paste costs | stillsuit tests |
| [0093](0093-launcher-model-v4-checks.md) | Launcher model checks run under QML V4, with node limits only catching gross regressions | stillsuit tests |
| [0094](0094-launcher-shell-icon-pack.md) | Launcher non-app rows use Stillsuit icon pack glyphs | stillsuit tests |
| [0095](0095-menu-host-headless-sway-fixture.md) | The menu-host fixture shapes headless sway around missing input and parked-surface stalls | stillsuit tests |
| [0096](0096-notifications-resident-sender-over-dbus.md) | Notification fixtures send resident notifications over D-Bus, not notify-send | stillsuit tests |
| [0097](0097-sessionizer-remote-access.md) | Sessionizer reaches other hosts only through the agent key, open login connections and a fixed remote path | sessionizer |
| [0098](0098-sessionizer-proxy-sessions.md) | Remote sessions show through one local proxy session per host | sessionizer |
| [0099](0099-sessionizer-bounded-git-reads.md) | Sessionizer caches git details by fingerprint and bounds every git and file read | sessionizer |
| [0100](0100-sessionizer-stable-rows.md) | Host refreshes never move rows in an open picker | sessionizer |
| [0101](0101-sessionizer-python-picker-formats.md) | Keep the Python picker's inventory and favorites formats | sessionizer |
| [0102](0102-sessionizer-e2e-fixture.md) | Sessionizer end-to-end tests run against an isolated three-server tmux fixture | sessionizer |
| [0103](0103-commit-hook-checks.md) | Commit hooks run per-file statix and a narrowed qmllint syntax check, with narrow lint exceptions | tooling/CI |
| [0104](0104-binary-cache-ci-plan-and-build.md) | The cache plan evaluates ungrafted host systems and passes derivations to build jobs | tooling/CI |
| [0105](0105-flake-lock-verify-nix-input-semantics.md) | flake-lock-verify follows Nix's own input resolution rules | tooling/CI |
| [0106](0106-unattended-update-jobs.md) | Unattended update jobs run from store copies, commit only their own files and retry only fetch failures | tooling/CI |
| [0107](0107-rebuild-review-explicit-returns.md) | rebuild's review function returns explicitly on every failure | tooling/CI |
| [0108](0108-edit-block-list-requires-a-terminal.md) | edit-block-list refuses to run without a terminal | tooling/CI |
| [0109](0109-tracer-archive-and-digest.md) | Tracer archives are pushed with merge-preserving tracer push, and tracer-digest marks processed sessions with a tag | tooling/CI |
| [0110](0110-obsidian-reconcile-best-effort.md) | obsidian-reconcile re-syncs externally written vault files on a best-effort basis | tooling/CI |
| [0111](0111-meeting-minutes-codex-tool-isolation.md) | Meeting-minutes Codex runs expose only a fixed, harmless tool set | tooling/CI |
| [0112](0112-meeting-minutes-context-heuristics.md) | Meeting-minutes context and speaker heuristics | tooling/CI |
| [0113](0113-meeting-minutes-job-state-and-files.md) | Meeting-minutes job state, caches and media files survive crashes and reloads | tooling/CI |
| [0114](0114-agent-run-record-consistency.md) | agent-run reads run records under the launch lock and resumes Codex by id | agent tooling |
| [0115](0115-agent-browser-smoke-isolated-environment.md) | agent-browser-smoke runs with a scrubbed browser environment | agent tooling |
| [0116](0116-sync-agent-skills-activation-path.md) | sync-agent-skills runs with Home Manager activation's minimal PATH | agent tooling |
| [0117](0117-tmux-resurrect-agents-cpa-restore.md) | tmux-resurrect-agents restores agents through their CPA wrappers | agent tooling |
| [0118](0118-hitl-loop-capture-not-for-credentials.md) | The HITL loop template keeps credentials out of capture | agent tooling |
| [0119](0119-acu-wl-copy-output-discarded.md) | acu discards wl-copy's output instead of capturing it | agent tooling |
| [0120](0120-blender-framing-camera-short-side.md) | The framing camera fits the subject to the image's shorter side | agent tooling |
| [0121](0121-opencode-jupyter-tool-format.md) | The opencode Jupyter tool fits cell IDs to nbformat 4.5 and builds its ANSI pattern for the linter | agent tooling |
| [0122](0122-pele-diagram-css-zero-specificity.md) | Pele diagram colours derive from the page and stay overridable | agent tooling |
