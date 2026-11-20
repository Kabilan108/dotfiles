# Nix access tokens reach root and user Nix through links to agenix files

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Root's Nix reads `/etc/nix/nix.conf`, so a file it includes must not be writable by kabilan: a kabilan-owned copy could be rewritten to load plugins into root's Nix. The unprivileged Nix client also needs a token for flake fetching. Codex's sandbox hides `/run/agenix`. Nix ignores its whole config when an include path is in a hidden directory, but skips an unreadable link.

## Decision

- Two agenix copies of `secrets/nix-access-tokens.age`: one owned by root for root's Nix, one owned by kabilan for the user client.
- `/etc/nix/access-tokens.conf` and `~/.config/nix/access-tokens.conf` are links to those agenix paths, included with `!include`, instead of including `/run/agenix` directly.

## Consequences

Inside the Codex sandbox the include is skipped and Nix keeps working without the token.

## Where

- `user.nix` (`secrets/nix-access-tokens.age`, `secrets/nix-access-tokens-user.age`, `environment.etc."nix/access-tokens.conf"`, the Home Manager `nix/access-tokens.conf` link)
