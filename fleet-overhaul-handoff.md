# Handoff: fleet workflow overhaul — follow-ups & priorities

Session: 2026-07-12, on sietch, repo `~/dotfiles` (branch `nixos`, all work
committed & pushed through `chore(raspi): sync sessionizer + tmux.conf`).
Origin: analysis of Theo's Linux-fleet video (transcript was extracted with
`summarize`), compared against this fleet, then all 7 phases of the resulting
plan were implemented in one session.

## Authoritative context (do not duplicate — read these)

- `docs/fleet-plan.md` — the phased plan, all marked done, with decision log
  (YubiKey-over-Tailscale-SSH rationale, trust matrix, per-phase outcomes).
- `docs/security-hardening.md` — the threat model everything defers to
  ("malware eventually runs as my user").
- `docs/tailscale-policy.jsonc` — reference copy of the applied tailnet
  policy (console is source of truth; keep this file in sync).
- `lib/fleet.nix` — the registry driving ssh config, authorized_keys,
  knownHosts, host colors, computers.md, sessionizer hosts.
- Issues: [dotfiles#8](https://github.com/Kabilan108/dotfiles/issues/8)
  (enable tracer-digest after vault reorg),
  [tracer#3](https://github.com/Kabilan108/tracer/issues/3) (metadata /
  list --json / titles / summaries / tagging),
  [pagebin#1](https://github.com/Kabilan108/pagebin/issues/1) (watch
  robustness, client-side id→URL cache; evidence comment appended).
- Memory: `fleet-remote-dev-goals.md` in the project memory dir.

## State snapshot (verified, not aspirational)

Fleet: jacurutu (control plane, blue) → sietch (agent worker, mauve) →
tleilax (appliance/future agent box, green; ONLINE, rebuilt, has its own
`~/dotfiles` clone). Directional ACL enforced (sietch→jacurutu verified
blocked). Human SSH is **hardware-only**: jacurutu's `id_ed25519` is no
longer authorized anywhere — yk-nfc travels with the user, yk-nano is the
backup living plugged into sietch (handle file stays on jacurutu; recovery =
fetch nano, plug into laptop). Agents = `<host>-agent` aliases (restricted
keys, BatchMode). tmux-on-ssh + `rawssh` escape hatch.
Fleet sessionizer 0.3.0 (client-swap via `detach-client -E`, returns to the
exact origin session). tracer-sync live (1,521 jacurutu transcripts in
`/vault/userdata/tracer-ingest/jacurutu/`); tracer-digest built,
deliberately NOT enabled. Skills shipped: `fleet`, `notify`, `html-plans`.
discord-notify CLI verified end-to-end; Executor stays locked down by design.

## Concrete follow-up tasks

1. **User housekeeping (small, do soon)**
   - Delete on both machines: `~/.ssh/known_hosts.old`, `~/.ssh/config.pre-fleet`,
     `~/.ssh/agent/` (kill orphan ssh-agents on jacurutu first — they hold
     zero identities; origin never identified, watch for recreation).
   - jacurutu only: delete `~/.ssh/sietch{,.pub}` (retired "ci@github.com"
     key — confirmed unused by any CI; already out of authorized_keys).
   - GitHub SSH keys were already rotated by the user post-exposure.
2. **Vault reorg → enable digest** — tracked in dotfiles#8 with exact steps
   (manual `tracer-digest` run first, judge output, tune prompt in
   `bin/tracer-digest`, set `digestDir`, flip `tracer-digest.enable`).
3. **tracer#3 implementation** (tracer repo, separate session): frontmatter
   metadata + `tracer list --json --since` first — they collapse the digest
   script's find/seen.txt half. Titles/summaries/tagging after. Search:
   deliberately deferred (rg + list filters likely suffice).
4. **pagebin#1**: watch daemon-mode/idempotent publish + local id→URL cache.
   The `html-plans` skill works around both today.
5. **tleilax as the "hermes" agent box** (hermes = planned concept, no code
   yet): define what runs there; give the Pi bashrc parity (it has no
   tmux-on-ssh guard or NO_TMUX handling — `raspi/config` has no bashrc);
   consider a network KVM (~$70–90 JetKVM/GL.iNet Comet) only if it lives
   somewhere physically inconvenient.
6. **raspi flake duplication**: `raspi/` is a separate flake root, so it
   cannot import `../lib/fleet.nix` — authorized_keys/bin/config are
   hand-synced mirrors (marked with comments). Structural fix when Pi work
   gets serious: merge tleilax into the main flake or move the flake root.
7. **t3 follow-ups**: bump `agent-server.t3Version` deliberately past 0.0.27
   when the connection issue is fixed upstream; optionally test fronting as
   a Tailscale Service (`svc:t3`) — depends on the desktop/mobile app
   pairing over https/wss; watch for the T3 Connect + mobile app releases.

## Prioritized recommendations (reflection on the whole arc)

1. **Adoption beats more infra.** The entire point (from Theo's video) was
   long-horizon jobs on the server while the laptop stays free. Everything
   needed for that now exists: `M-s` to dive in, `<host>-agent` for
   dispatch, `html-plans` for deliverables, `notify` for completion. The
   next win is habit: end long sietch jobs with "publish the plan/report
   via pagebin and notify me" — the skills make that a one-line suffix.
2. **The separate `agent` unix user is now the top security priority.**
   The hardware-only flip is done (id_ed25519 dropped from human logins),
   and testing it immediately exposed the remaining hole: a YubiKey-less
   login still succeeded because gcr's ssh-agent offered the passwordless
   `agent-jacurutu` key (confirmed via sshd fingerprint log). The implicit
   path is closed (`IdentitiesOnly yes` on human stanzas), but the agent
   keys remain a deliberate software path to a FULL SHELL as `kabilan` —
   malware-as-user just runs `ssh sietch-agent`. Per security-hardening
   §agents: dedicated `agent` user, no sudo, scoped dirs, own home; when
   done, only the `User` line in the generated `-agent` aliases changes.
   This is the difference between a hardware-gated human *path* and a
   hardware-gated *account* — schedule it as its own session.
3. **The digest loop is the highest-leverage unproven piece.** 2,100+
   transcripts across both roots is real training data about how you work.
   One manual `tracer-digest` run costs minutes and will tell you whether
   the weekly loop earns its tokens — don't let dotfiles#8 rot.
4. **Keep the ACL and its reference copy in lockstep.** Two drifts happened
   in one day (pixel-9 tweak, svc:siren fix). The `tests` block is the
   safety net — extend it whenever a new dependency appears (e.g.
   `tleilax:8787` for the phone remote).
5. **Skip CMUX-chasing.** Confirmed macOS-only; the sessionizer client-swap
   plus t3-over-tailnet covers the same jobs. Revisit only if the unofficial
   Linux ports mature.

## Gotchas learned this session (will bite again)

- `EDITOR="cp src" agenix -e` silently writes EMPTY .age files with this
  agenix version — always encrypt with `age -r <recipient>` directly and
  verify round-trip with `age -d | cmp -s`. Also: verifying with
  `EDITOR=cat agenix -e` RE-ENCRYPTS on exit and can clobber the file.
- tmux name-based targets misparse `/`, `@`, and spaces (even with `=`
  exact-match) — always resolve to `#{session_id}` and target by id.
- `nixos-rebuild --build-host <remote>` from inside the flake dir trips the
  "missing essential files" sanity check (nix#13367): `cd $HOME` first, or
  rebuild on the target device.
- Backgrounding long processes with `&` inside an agent Bash call kills
  them when the call returns — use detached tmux sessions.
- Tagged tailscale devices (`tag:server`) silently drop out of
  `autogroup:member`/`autogroup:self` — every member-scoped grant/ssh rule
  needs an explicit tag counterpart (this broke dictator→siren for a bit).
- Fleet ssh stanzas list YubiKey identities first: any scripted ssh through
  the plain host alias can hang on touch — scripts must use `<host>-agent`.
- ssh offers every key the desktop ssh-agent (gcr) holds IN ADDITION to the
  stanza's IdentityFile list — without `IdentitiesOnly yes`, an unlisted
  software key can silently satisfy auth and defeat the hardware-key
  requirement. Verify auth-path changes against sshd's "Accepted publickey"
  fingerprints, and test with the YubiKeys unplugged AND `ssh -O exit` first
  (a live ControlMaster skips authentication entirely).

## Suggested skills for the next session

- `fleet` — before touching any cross-machine work (topology + rules).
- `notify` / `html-plans` — end long jobs with a notification / published
  artifact; also the reference implementations for skill conventions here.
- `commit` — repo uses conventional-ish commits (`feat(fleet): …`).
- `update-image-pins` / `add-selfhost-service` — for sietch service work.
- `/code-review` before merging tracer#3 work in the tracer repo.
