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

### Phase 1 — fleet registry + SSH hygiene + tmux/colors [in progress]

- [x] `lib/fleet.nix` — declarative registry (roles, IPs, colors, roots,
      access matrix, keys); single source for everything below
- [x] Generated SSH client config (`programs.ssh.settings` via
      `modules/home/fleet.nix`) + private include (`~/.ssh/config.d/private`,
      agenix, both machines)
- [x] Flake-managed authorized_keys (`modules/nixos/fleet.nix`, computed from
      the access matrix); `PasswordAuthentication = false` on sietch
- [x] sietch private keys into agenix (`secrets/ssh/sietch/*.age`, verified
      round-trip); `agent@sietch` keypair generated and authorized on tleilax
- [ ] jacurutu private keys into agenix (run on jacurutu; declarations
      activate automatically via pathExists once the .age files exist)
- [x] YubiKey `ed25519-sk` keys generated on jacurutu; pubkeys in
      `keys.human` (yk-nfc, yk-nano); handles flake-managed via agenix once
      encrypted
- [x] tmux-on-SSH: interactive-shell guard in `config/.bashrc`
- [x] Per-host colors: PS1 via `FLEET_HOST_ANSI`, tmux via generated
      `~/.config/tmux/host.conf` (jacurutu blue, sietch mauve, tleilax green)
- [x] Generated `~/.config/fleet/computers.md` + `fleet` agent skill
- [ ] Rebuild sietch, verify key-only login from jacurutu, then rebuild
      jacurutu

### Phase 2 — fleet-aware sessionizer

Merge local + remote tmux sessions and dirs into one host-colored fzf picker
(`host:session` rows, preview pane, attach locally or `ssh -t <host> tmux new
-A -s <session>`). Registry-driven.

### Phase 3 — Tailscale ACL rewrite

Remove both allow-all grants; directional grants per the trust table
(pixel-9 keeps broad access to sietch+jacurutu); keep `svc:` grants and
autoApprovers; add `tests` asserting sietch cannot reach jacurutu. Add
tleilax to `hosts`. Execute while at jacurutu with the old policy saved.

### Phase 4 — t3 service polish

Pin t3 version as a module option in `agent-server.nix` (currently unpinned
`npx t3 serve`; the 0.0.27 pin exists only in the live tmux pane). Review t3
docs for built-in tailscale support; decide raw port 3773 vs Tailscale
Service.

### Phase 5 — discord-notify unblock

Executor (v1.5.29) blocks tailnet hostnames (`HostedOutboundRequestBlocked`)
and has no per-host allowlist. Direction: local agents call discord-notify
directly (CLI/tailnet URL) keeping `EXECUTOR_ALLOW_LOCAL_NETWORK=false`;
Executor-mediated notify only for sandboxed contexts (CF tunnel if needed).
Taking over from the rate-limited codex session (transcript 019f4f80).

### Phase 6 — pagebin html-plans skill

Mine sietch tracer archive for real pagebin usage; build the skill from
observed patterns; fold learnings into pagebin improvements
(Kabilan108/pagebin#1).

### Phase 7 — tracer ingestion + learning loop

jacurutu → sietch one-way archive sync; targeted tracer improvements;
periodic review job distilling sessions into the agent wiki. Needs a
dedicated discussion.

## Open items

- Rotate sietch's `~/.ssh/github` key: its private key material was printed
  into an agent session transcript (2026-07-12) during agenix verification.
  Low exposure (local transcripts + API logs) but rotate on principle.

- Retire the `ci@github.com` keypair: confirmed identical to jacurutu's
  `~/.ssh/sietch` login key, and the repo has no deploy keys or SSH-using
  workflows, so nothing in CI uses it. After YubiKey + `id_ed25519` logins
  are verified on sietch, remove it from `extraAuthorizedKeys` in
  `lib/fleet.nix` and delete `~/.ssh/sietch{,.pub}` on jacurutu.
- `~/.ssh/agent/` sockets: stale on sietch (Mar 26, no listener — delete);
  LIVE on jacurutu (three listeners as of 2026-07-12) — identify owner via
  `sudo lsof` before removal.
- tleilax host key for knownHosts; add when the Pi is reachable.
- Separate `agent` unix user (security-hardening §agents) — deferred; agent
  keys land first, user split later.
