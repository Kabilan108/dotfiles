# Security Hardening Plan

> Living document. Captures decisions, rationale, and open questions for hardening
> accounts, machines, and dev workflow. Drafted 2026-06. Iterate freely.

## Threat model (what we're actually defending against)

Primary assumption: **a credential stealer / supply-chain payload will eventually
execute as my user on a dev machine** (sietch / jacurutu). This is well-founded —
the Shai-Hulud worm campaign (Sept 2025 → "Mini Shai-Hulud" hit npm + PyPI
simultaneously, Apr 2026) is exactly this: self-propagating, harvests tokens / env /
files, some variants wipe `$HOME`.

What hardware keys DO against this: credentials are non-exportable (can't be
replayed from attacker infra) + phishing-resistant.

What they DON'T do: stop session/cookie theft, stop reading plaintext secrets on
disk, stop abuse while the vault is unlocked. Those need **isolation + getting
secrets off disk**, which is the higher-priority track.

### Priority order (highest ROI first)
1. Hardware 2FA on the vault + crown-jewel accounts (replay resistance).
2. Get plaintext secrets off disk (recovery codes, registry tokens, `.env`s).
3. Isolation/sandboxing for untrusted code run by agents.
4. Hardware-backed SSH keys (`ed25519-sk`) for interactive login.
5. Sane backups (NAS + offsite) — insurance against the destructive payloads.

---

## Hardware: the two YubiKeys (5C NFC + 5C nano, fw 5.7)

- **5C NFC** = daily carry (laptop + phone via NFC).
- **5C nano** = parked backup in sietch front USB-C.
- **3rd key** = planned next month, stored offsite. Until then, offline recovery
  codes are the third leg.

**Iron rule:** every credential enrolled on one key must be enrolled on BOTH keys,
done while still authenticated to the account. Implication: future 2FA setup must
happen at home where both keys are present.

YubiKey functions in play:
- **FIDO2/WebAuthn** — passkeys (resident, ~100 slots on fw5.7) + security-key-2FA
  (non-resident, effectively unlimited). The main event.
- **OATH-TOTP** (Yubico Authenticator) — TOTP seeds stored on the key.
- **PIV/OpenPGP** — only if used for SSH/signing (see below).
- **Yubico OTP** — NOT USED. Ignore entirely. No self-hosting, no setup needed.

---

## Account tiering

### Tier 1 — Crown jewels (hardware-direct, both keys)
Accounts where compromise is catastrophic. Use **passkey** where passwordless is
offered, else **security-key-2FA**. No TOTP unless forced (then TOTP on the keys).

- [ ] Vaultwarden (do FIRST)
- [ ] Email / Outlook (reset path for everything)
- [ ] Google account
- [ ] GitHub
- [ ] Anthropic
- [ ] OpenAI (passkey already done ✓)
- [ ] Bank of America (verify whether it supports passkey/security-key)
- [ ] DNS / domain registrar
- [ ] Cloud provider root/IAM
- [ ] (add as discovered)

**Passkey vs security-key-2FA:** "create a passkey / go passwordless" → passkey.
"register a security key" under 2FA → 2FA mode. Use 2FA mode to conserve resident
slots, avoid discoverable creds, or for shared/work accounts.

### Tier 2 — Ordinary accounts
- Passwords: strong + unique in Vaultwarden.
- Passkeys: stored in Vaultwarden (syncable, recoverable, phishing-resistant).
- TOTP: default to **Yubico Authenticator** (keeps factor separate from the vault,
  removes Google-cloud dependency). Vaultwarden-TOTP only for genuinely throwaway
  accounts.

---

## TOTP policy (replacing Google Authenticator)

- Seeds live **on the YubiKeys**; phone app (via NFC) is the daily reader.
- Migrate per-account during the password sweep: add to Yubico Authenticator,
  **save to BOTH keys**, then delete from Google Authenticator.
- No machine-side setup required for phone-only use (no pcscd needed).
- Desktop Yubico Authenticator (needs `services.pcscd.enable`) only if bulk
  keyboard enrollment is preferred over phone-camera. Optional.
- Crown-jewel TOTP fallbacks (when a site has no FIDO2) → on the keys, NOT the vault.

---

## Vaultwarden hardening

Good news: Vaultwarden is **zero-knowledge** — vault data is encrypted client-side
with the master password. The `vaultwarden-data` volume holds ciphertext; FDE is a
secondary layer. The real attack surface is the **decrypted client session**.

### Server side (`selfhost/compose.yml`)
- [ ] **Pin image to a digest** (not `:latest`) — supply-chain hygiene. HIGH PRIORITY.
- [ ] Remove the commented `ADMIN_TOKEN` (not used). If ever needed, use an
      Argon2-hashed token, Tailscale-only.
- [x] `SIGNUPS_ALLOWED: false`
- [x] Tailscale-only access, no public exposure
- [ ] Ensure `vaultwarden-data` volume is in the backup set (see Backups).

### Client side (where it actually matters)
- [ ] **WebAuthn 2FA, both keys** (do first). Use WebAuthn, NOT Yubico OTP.
- [ ] **Shorten vault timeout** drastically (15–30 min or "on system lock").
- [ ] Timeout action = **lock**; require master password / biometric on unlock.
- Desktop app does NOT replace the browser extension (extension does autofill).
  It can hold biometric-unlock state for the extension, but Linux fprintd setup is
  fiddly — skip unless wanted; shortening the extension timeout gets ~90% of the win.
- Residual risk: malware running while vault is unlocked → handled by sandboxing track.
- [ ] Store the **Vaultwarden recovery code OFFLINE** (not in the vault — circular).

---

## Recovery codes & secrets at rest

- **Crown-jewel recovery codes** → printed, **offline**, in a drawer (+ copy with the
  future 3rd key). Reprint the relevant slip when a code rotates. Rationale: agenix
  secrets are encrypted to *host* keys that live on the machine, so a root compromise
  decrypts them — crown jewels must sit outside that blast radius.
- **Non-crown secrets / recovery codes** → **agenix** (existing pattern: `secrets/*.age`,
  encrypted to `sietch` + `jacurutu`, committed to repo). Safe to commit ciphertext;
  the age identity (host keys) must never be in the repo.
- **DELETE the plaintext recovery-codes file tonight.** (Highest-exposure item: a
  `600` plaintext file defeats everything else the instant malware runs as me.)
- **Registry/publish tokens:** eliminate long-lived tokens where possible.
  - [ ] PyPI **Trusted Publishing (OIDC)** for published packages — no stored token.
  - [ ] Other tokens → agenix at rest; inject at runtime.
- **"Fetch secret via command" pattern:** only adds security combined with sandboxing
  (the fetch command lives outside the agent's sandbox). On its own, malware-as-me
  runs it too.

---

## SSH hardening

Status: OpenSSH 10.3 supports `sk-ssh-ed25519` ✓. `ykman` not installed yet;
confirm `libfido2` present when generating the first sk key.

### Split: interactive vs automation
- **Interactive (human → sietch/jacurutu/raspi):** `ed25519-sk` hardware key, touch
  per login. Generate one sk key per YubiKey, add both pubkeys to `authorized_keys`.
  Consider `-O resident` so the key can be re-derived onto a fresh machine via
  `ssh-keygen -K`.
- **Automation (nix private flake fetch, agenix host identity, deploy keys):** stays a
  **software** key. Do NOT move onto the YubiKey — every `nixos-rebuild` would need a
  touch. Keep as scoped, read-only deploy keys; manage via agenix.

→ Hardware keys and agenix are **complementary**, not either/or.

### Agents that SSH
- Separate unix user (e.g. `agent`) with its own plain `ed25519` key (agents can't
  touch hardware). Lock down in `authorized_keys`:
  `restrict,from="<tailnet CIDR>",command="..."`, no agent-forwarding. No sudo,
  scoped directories.
- **Strongly consider Tailscale SSH**: moves auth to tailnet ACLs, supports per-rule
  re-auth (`checkPeriod`), tag-based identity for OpenClaw/Hermes on the Pi. Cleaner
  than hand-managed `authorized_keys` across 3 hosts.
- The Pi (OpenClaw / Hermes) raises stakes: human access = hardware key; agent runtime
  = constrained identity, sandboxed, no path to human creds.

---

## Git commit/tag signing

- Scope per-repo via conditional include in `~/.gitconfig`:
  ```
  [includeIf "gitdir:~/code/published/"]
      path = ~/.gitconfig-signing
  ```
  with `commit.gpgsign`/`tag.gpgsign = true`, `gpg.format = ssh`,
  `user.signingkey = ~/.ssh/id_ed25519_sk.pub`.
- Sign with the **`ed25519-sk`** key (hardware-backed, can't be stolen).
- Scope: **published packages only** (sign release tags primarily). Personal repos:
  skip. Work/medical-device: legitimate given regulated context, but it's an org
  rollout — raise with team, don't solo.

---

## Isolation / sandboxing (separate deep-dive)

- Altitude: **bubblewrap** (or `systemd-run --user` with `ProtectHome`/`BindPaths`,
  or rootless podman) to lock agents to their project dir. Firecracker/microVMs are
  overkill unless running genuinely hostile, escape-attempting code.
- This is the track that actually addresses the primary threat (malware-as-me) —
  prioritize alongside getting secrets off disk.

---

## Backups (separate deep-dive — own session/agents)

Current `bin/backup` only pushes screenshots/recordings to Google Drive — inadequate.

Open items:
- [ ] Include the `vaultwarden-data` volume.
- [ ] 3-2-1 strategy: NAS at home (both machines), offsite later this year.
- [ ] Encrypt backups at rest (esp. anything leaving the house / Google Drive).
- [ ] Immutable / offline copy specifically to survive destructive (wipe) payloads.
- [ ] Reconsider Google Drive as the target.

---

## Explicitly DESCOPED (decided against, for this threat model)

- **LUKS-via-YubiKey** — protects against physical theft / evil-maid, irrelevant to
  malware-on-running-machine. Keep the strong in-head passphrase.
- **sudo-via-YubiKey** — not the boundary when malware runs as me; breaks remote SSH.
  Keep sudo on password (+ fingerprint on laptop).
- **Yubico OTP / YubiCloud self-hosting** — not used at all.
- **Git signing for personal/work repos** — published packages only.

---

## NixOS / flake changes needed (minimal)

- [ ] Install `ykman` (yubikey-manager) for FIDO2 PIN + key management.
- [ ] Confirm `libfido2` available for `ed25519-sk` (test by generating a key).
- [ ] `services.pcscd.enable = true` — ONLY if adopting desktop Yubico Authenticator
      or GPG/PIV-on-card. Not needed for phone-NFC TOTP or browser passkeys.
- Browser passkeys already work with zero flake changes (FIDO2 over hidraw).

---

## Sequenced rollout

**Phase 0 — tonight**
- [ ] Delete the plaintext recovery-codes file.
- [ ] Set FIDO2 PIN on both keys (`ykman`), record offline.

**Phase 1 — vault + foundation**
- [ ] WebAuthn 2FA on Vaultwarden (both keys) + save recovery code offline.
- [ ] Shorten vault timeout, require master password on unlock.
- [ ] Pin Vaultwarden image digest.

**Phase 2 — account sweep (manual, ongoing)**
For each account in Vaultwarden:
- [ ] Rotate weak/leaked passwords → strong + unique.
- [ ] Decide tier. Crown jewel → passkey/security-key on both keys.
- [ ] TOTP present → migrate to Yubico Authenticator (both keys), drop from Google Auth.

**Phase 3 — SSH + dev hardening**
- [ ] Generate `ed25519-sk` keys (per YubiKey), deploy to hosts.
- [ ] Set up agent user(s) + Tailscale SSH ACLs.
- [ ] PyPI trusted publishing for published packages.
- [ ] Git signing config for published repos.

**Phase 4 — isolation + backups** (separate sessions)
- [ ] Bubblewrap/sandbox for agent workdirs.
- [ ] Backup overhaul (NAS, encryption, offsite).

**Phase 5 — when 3rd key arrives**
- [ ] Enroll on all Tier 1, store offsite, move recovery codes there too.

---

## Open questions to resolve later
- Bank of America: passkey / security-key support?
- Desktop secrets broker: Infisical vs 1Password CLI vs agenix-at-runtime?
- Tailscale SSH vs raw sshd for the human + agent split?
- Backup target if not Google Drive; backup encryption scheme.
- Bitbucket helper tool: how to broker its secret without exposing it to a shell?
