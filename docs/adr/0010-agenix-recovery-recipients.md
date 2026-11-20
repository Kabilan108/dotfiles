# Secrets used on one host keep a second recipient for recovery

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Some secrets are decrypted only on sietch, such as the Hark Android release keystore and signing properties and the personal keystore every Android app on Tony's phone is signed with. Losing them would mean re-signing every app. The YubiKeys' age identities live on PIV.

## Decision

- Those files list jacurutu's key as well as sietch's, as a second way to recover them, while `user.nix` installs them only on sietch.
- jacurutu runs pcscd so the YubiKey age identities work; agenix finds `age-plugin-yubikey` on PATH when a recipient is an `age1yubikey1…` key.

## Consequences

Anyone running as kabilan on jacurutu can decrypt these files today; the re-key plan in `docs/security-hardening.md` moves secrets to host keys plus YubiKeys.

## Where

- `secrets.nix` (Android and Hark keystore entries)
- `machines/jacurutu/default.nix` (`services.pcscd`, `age-plugin-yubikey`)
