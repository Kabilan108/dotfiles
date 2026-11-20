# Hosts with a NAS get a root-only SSH host key before backups run

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Each host's backup secrets (SMB login and Restic password) are encrypted to its SSH host key, `/etc/ssh/ssh_host_ed25519_key`. jacurutu runs no sshd, so nothing else creates that key there. agenix skips identities it can't read. The backup VM test has no agenix.

## Decision

When `dotfiles.backup.nas` is set, the activation script `backupHostKey` creates an ed25519 host key if none exists, and the host key is appended to `age.identityPaths` with `mkAfter`. The identity is added only when the `age` option exists, so the VM test evaluates without agenix. The key is added whether or not backups are enabled, so the key exists before backups are switched on.

## Consequences

- Before the key exists, agenix ignores the missing identity, so the first activation does no harm.
- The same root-only key authenticates status pushes to the status host (`BACKUP_PUSH_KEY`).
- A new host's public key has to be registered as a recipient of its backup secrets before they decrypt (docs/backups.md).

## Where

- `modules/nixos/backup/default.nix` (`system.activationScripts.backupHostKey`, `age.identityPaths`, `hostKey`)
