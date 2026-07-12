# Fleet workflow plan

Tracking doc for the remote-dev / fleet-management overhaul (inspired by Theo's
Linux-fleet setup, adapted to this repo's security model). Companion to
[security-hardening.md](./security-hardening.md).

## Fleet & trust model

| host | role | tailnet IP | trust | can ssh into |
|------|------|-----------|-------|--------------|
| jacurutu | control plane (Framework laptop, daily driver) | 100.108.28.4 | human, highest | sietch, tleilax |
| sietch | agent worker (server; runs day-job agent sessions, selfhost services) | 100.71.183.33 | agents-run-here | tleilax |
| tleilax | appliance (Pi 4; future agent box) | 100.73.84.103 | lowest | nothing |

Decisions (2026-07-12):

- sietch → jacurutu: **no**. jacurutu is the brain; nothing SSHes into it.
- Human SSH: hardware-backed `ed25519-sk` keys (both YubiKeys enrolled), raw
  OpenSSH. **Not** Tailscale SSH — within a check-mode window, malware-as-user
  on a trusted device can ride the session; hardware touch defeats exactly
  that. Revisit if the fleet grows or session recording becomes interesting.
- Agent SSH: separate constrained software keys per source machine
  (`agent@<host>`), restricted authorized_keys entries, managed via flake.
- Tailscale account already passkey-protected (GitHub auth + YubiKey 2FA).
- Private keys: agenix, encrypted per-machine (jacurutu-only keys to
  jacurutu's recipient only — sietch must not be able to decrypt them).
  `~/.ssh/id_ed25519` stays out of agenix on every host (it *is* the agenix
  identity).
- Work SSH stanzas (office-VPN IPs, usernames) stay out of the public repo:
  agenix-managed include at `~/.ssh/config.d/work`.
- Tracer: sietch's archive is authoritative; jacurutu syncs one-way into it
  (phase 7).

## Phases

### Phase 1 — fleet registry + SSH hygiene + tmux/colors [done 2026-07-12]

- [x] `lib/fleet.nix` — declarative registry (roles, IPs, colors, roots,
      access matrix, keys); single source for everything below
- [x] Generated SSH client config (`programs.ssh.settings` via
      `modules/home/fleet.nix`) + private include (`~/.ssh/config.d/private`,
      agenix, both machines)
- [x] Flake-managed authorized_keys (`modules/nixos/fleet.nix`, computed from
      the access matrix); `PasswordAuthentication = false` on sietch
- [x] sietch private keys into agenix (`secrets/ssh/sietch/*.age`, verified
      round-trip); `agent@sietch` keypair generated and authorized on tleilax
- [x] jacurutu private keys into agenix (all eight verified OK, 2026-07-12)
- [x] YubiKey `ed25519-sk` keys generated on jacurutu; pubkeys in
      `keys.human` (yk-nfc, yk-nano); handles flake-managed via agenix once
      encrypted
- [x] tmux-on-SSH: interactive-shell guard in `config/.bashrc`
- [x] Per-host colors: PS1 via `FLEET_HOST_ANSI`, tmux via generated
      `~/.config/tmux/host.conf` (jacurutu blue, sietch mauve, tleilax green)
- [x] Generated `~/.config/fleet/computers.md` + `fleet` agent skill
- [x] Rebuild sietch, verify key-only login from jacurutu (id_ed25519 +
      yk-nfc confirmed), rebuild jacurutu
- [x] ci@github.com key removed from extraAuthorizedKeys (takes effect on
      next sietch rebuild; also delete `~/.ssh/sietch{,.pub}` on jacurutu)

### Phase 2 — fleet-aware sessionizer [done 2026-07-12]

sessionizer 0.3.0: merges local sessions, remote fleet sessions, and dirs in
one fzf picker with host-colored rows and a preview pane. Remote listing uses
the `agent-<host>` key with BatchMode + 1s timeout (never blocks on YubiKey
touch); selecting a remote session opens/reuses a local window named
`<host>/<session>` running `ssh -t <host> tmux new -A`. Fleet SSH stanzas
gained ControlMaster/ControlPersist 4h, so interactive attaches touch the
YubiKey at most once per host per window. Hosts come from generated
`~/.config/fleet/hosts`. M-s popup enlarged to 80%x70%.

### Phase 3 — Tailscale ACL rewrite

Remove both allow-all grants; directional grants per the trust table
(pixel-9 keeps broad access to sietch+jacurutu); keep `svc:` grants and
autoApprovers; add `tests` asserting sietch cannot reach jacurutu. Add
tleilax to `hosts`. Execute while at jacurutu with the old policy saved.

### Phase 4 — t3 service polish [done 2026-07-12]

`agent-server.t3Version` module option pins t3 (default 0.0.27; bump
deliberately). Docs review: t3 has no dedicated tailscale integration — only
`--host` binding (already done) and an `--auth-token` flag; T3 Connect not
shipped yet. Keeping the raw tailnet-IP:3773 bind. Optional follow-ups:
front with a Tailscale Service (`t3.sole-pierce.ts.net`) once confirmed the
desktop/mobile app pairs over https/wss, and add `--auth-token` if the
tailnet ever gets less trusted.

### Phase 5 — discord-notify unblock [done 2026-07-12]

Resolution: two paths, only one of which we need today.

- **Local agents (sietch/jacurutu)** use the `discord-notify` CLI directly —
  verified working end-to-end (webhook env from `.bashenv`, shared to both
  machines via agenix). New `notify` agent skill documents usage.
- **Executor-hosted agents** stay blocked by design: Executor v1.5.29 has no
  per-host outbound allowlist, and flipping `EXECUTOR_ALLOW_LOCAL_NETWORK`
  would expose loopback services (vaultwarden et al.) per
  security-hardening.md. If hosted agents ever genuinely need to notify,
  expose the bearer-authed service (127.0.0.1:8303) through a Cloudflare
  tunnel — do not loosen Executor.

### Phase 6 — pagebin html-plans skill [done 2026-07-12]

Mined ~6 heavy pagebin sessions from the tracer archive. `html-plans` skill
encodes the observed conventions: publish `--json` once and capture id+URL
immediately, `update` in place (stable URLs), run `watch` inside tmux (Bash
`&` backgrounding kills it — the top recurring failure), absolute paths,
30d/4w TTLs, deliver as bold link + notify skill. Evidence-backed CLI
priorities posted to Kabilan108/pagebin#1 (watch robustness, client-side
id→URL cache). Actual pagebin CLI changes happen in that repo, not here.

### Phase 7 — tracer ingestion + learning loop [dotfiles side done 2026-07-12]

- `tracer-sync` (jacurutu): daily systemd user timer rsyncing the archive to
  `sietch:/vault/userdata/tracer-ingest/jacurutu/` over the restricted
  `agent-jacurutu` key.
- `tracer-digest` (sietch): headless `claude -p` review of new sessions
  across both archive roots → digest markdown + discord-notify summary.
  First run auto-seeds sessions older than 14 days as seen. **Manual-first**:
  the weekly timer module exists but is not enabled — run `tracer-digest` by
  hand, tune the prompt/output, then enable `tracer-digest.enable` and set
  `digestDir` once the agent-wiki location is settled.
- Tracer CLI improvements (scoped for the tracer repo, separate session):
  frontmatter metadata (host/cwd/model/times), a search/index command,
  outcome tagging.

## Open items

- Rotate sietch's `~/.ssh/github` key: its private key material was printed
  into an agent session transcript (2026-07-12) during agenix verification.
  Low exposure (local transcripts + API logs) but rotate on principle.

- ci@github.com keypair retired from the registry (2026-07-12); delete
  `~/.ssh/sietch{,.pub}` on jacurutu when convenient.
- `~/.ssh/agent/` sockets: stale on sietch (Mar 26, no listener — delete);
  LIVE on jacurutu (three listeners as of 2026-07-12) — identify owner via
  `sudo lsof` before removal.
- ~~tleilax host key for knownHosts~~ — captured 2026-07-12 (Pi is online);
  in the registry. Pi still needs a rebuild from raspi/ to pick up the
  agent@sietch authorized key.
- Post-ACL regression, fixed in the reference policy 2026-07-12: sietch
  (tagged) lost `svc:` access when allow-all was removed, breaking dictator →
  siren on sietch. Add the `tag:server → svc:siren` grant in the console.
- Separate `agent` unix user (security-hardening §agents) — deferred; agent
  keys land first, user split later. **Priority raised 2026-07-12**: the
  hardware-only-human-ssh flip revealed that `agent-<host>` keys are a
  passwordless software path to a full shell as kabilan (gcr's ssh-agent
  even offered one implicitly — mitigated with IdentitiesOnly on human
  stanzas, but deliberate use is unaffected). The user split is what closes
  this for real.
