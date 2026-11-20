# Prebuilt vendor apps are extracted and verified, never patched

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

ChatGPT desktop and Grok Bot ship as Debian packages whose maintainer scripts add an apt source and an AppArmor profile. Helium ships signed release tarballs. Desktop sessions may carry `CODEX_*`, `XDG_*` and library-path variables that would redirect ChatGPT's profile and Codex configuration.

## Decision

- The `.deb` payloads are only extracted: no ELF, ASAR, launcher or feature patches, and dpkg maintainer scripts are not run.
- The ChatGPT launcher unsets those variables so the app uses the normal Electron profile and the intentional `~/.codex` configuration.
- Helium's runtime library list follows nixpkgs' google-chrome package. The pinned hash fixes the bytes, and `gpgv` against `helium-signing-key.asc` proves Helium published them.

## Consequences

Fixes that need patching go upstream or into a launcher, not into the vendor payload. A Helium signing-key rotation needs the new key committed.

## Where

- `packages/chatgpt-desktop.nix` (`payload`, `launcher`)
- `packages/grok-bot.nix` (`payload`)
- `packages/helium.nix` (`deps`, `postUnpack`)
