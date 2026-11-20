# System Docker refuses a replaceable data root, and kabilan owns ~/.config/moberg

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

- System Docker's data root is `/vault/userdata/docker`. kabilan has a named write ACL on `/vault` and `/vault/userdata` (docs/security-hardening.md). In a mode word, the group class also represents the effective POSIX ACL mask.
- agenix can create `~/.config/moberg` as root before Home Manager links Docker's user configuration (`moberg/docker.toml`) into it.

## Decision

- Before the daemon starts, `docker-storage-guard.py` checks `/`, `/vault`, `/vault/userdata` and `/vault/userdata/docker`: each must be a real root-owned directory, `/vault` and `/vault/userdata` must be sticky, and the others must have no group or other write bit, which also rules out an ACL that grants write. `/vault` must be a mount.
- A tmpfiles `d` rule sets `~/.config/moberg` to 0755 kabilan:users. It changes the directory's owner without touching the secrets inside.

## Consequences

Home Manager can link into `~/.config/moberg` even after agenix created it. A change to `/vault` permissions that grants group write stops system Docker at its next start.

## Where

- `modules/nixos/docker-storage-guard.py` (`verify_storage`)
- `modules/nixos/docker.nix` (`systemd.tmpfiles.rules`, `systemd.services.docker.preStart`)
