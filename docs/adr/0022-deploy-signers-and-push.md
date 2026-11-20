# Deploy tags are signed with a verify-required YubiKey key file and pushed as a deploy key

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Hosts deploy only commits approved by a YubiKey-signed `deploy/fleet/<UTC time>` tag (`docs/security-hardening.md`, "Fleet tags and waiting for the cache"). The receiver must know which commit a host runs to refuse moving backwards. GitHub's tag ruleset lets only the repo's deploy keys create `deploy/*` tags; pushing with the account key from `~/.ssh/config` or an agent would authenticate, then GitHub would refuse the tag.

- ssh-keygen signs through any ssh-agent that lists the key. GNOME Keyring's agent lists every `~/.ssh/*.pub` and can't ask for the YubiKey PIN.
- `ykman list` reads each key's serial over PC/SC or USB HID without a PIN or touch. Without pcscd it still reads them over the FIDO HID interface, which signing already needs. It logs every transport that fails to stderr, even when another one reads the key.
- `deploy` asks for confirmation on the terminal. A git pager would take the terminal and swallow the answer.

## Decision

- Every system sets `system.configurationRevision` from `self.rev` or `self.dirtyRev`; the receiver only moves forward from it.
- Signer keys are one per YubiKey, made with `ssh-keygen -t ed25519-sk -O verify-required`. They are separate from the touch-only login keys in `hosts.jacurutu.keys.human`, and each key's comment is its allowed-signers principal. `requirePin = true` also requires the PIN flag in signatures.
- `deploy-tag sign` unsets `SSH_AUTH_SOCK`, so ssh-keygen loads the key handle file and asks for the PIN on the terminal.
- Tags push over SSH (`git@github.com:Kabilan108/dotfiles.git`) so the signer key can authenticate as a deploy key. `deploy-tag push` runs ssh with `-F /dev/null`, `-i <key>`, `IdentitiesOnly=yes`, `IdentityAgent=none`, the pinned `DEPLOY_PUSH_KNOWN_HOSTS` file and `StrictHostKeyChecking=yes`. `pushKnownHosts` is GitHub's ed25519 host key from `gh api meta`.
- `deploy-key` maps YubiKey serials to key names and trusts only `ykman`'s exit status. One deploy YubiKey plugged in selects its key. More than one, a missing `ykman`, or a failed listing falls back to `deploy.defaultSigner` (yk-nfc-deploy). None plugged in exits 1 with instructions.
- `deploy` runs git with `--no-pager`.

## Consequences

- Each sign and each push takes the PIN and a touch.
- An agent with access to the account key can't create a deploy tag.
- A new YubiKey needs its own verify-required key, a matching principal comment, and its serial in `deploy.signerYubiKeys`.
- If GitHub rotates its SSH host key, refresh `pushKnownHosts` from `gh api meta`.

## Where

- `flake.nix` (`configurationRevision`)
- `lib/fleet.nix` (`deploy.signers`, `deploy.requirePin`, `deploy.pushUrl`, `deploy.pushKnownHosts`, `deploy.signerYubiKeys`, `deploy.defaultSigner`)
- `modules/nixos/deploy/deploy-tag.sh` (`sign`, `push`)
- `modules/nixos/deploy/deploy-key.sh`
- `modules/nixos/deploy/deploy.sh` (`g`)
