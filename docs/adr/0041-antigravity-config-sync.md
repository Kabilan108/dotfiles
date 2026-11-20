# Antigravity settings are merged in place and bridged into T3 profiles

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

`agy` rewrites `~/.gemini/antigravity-cli/settings.json` atomically, replacing symlinks, and writes elsewhere in `~/.gemini`. T3 Code isolates `GEMINI_HOME` per provider instance and symlinks only config and skills.

## Decision

- Home Manager links only `~/.gemini/config` to the checkout.
- `sync-antigravity-config` runs at activation. It merges the repository's CLI baseline into the live settings file, preserving runtime-added keys and `trustedWorkspaces`, and links `AGENTS.md`, `mcp_config.json` and `mcp_oauth_tokens.json` into existing T3 Antigravity profiles.

## Consequences

T3 disables Antigravity as a background text-generation model when a profile has a non-empty `mcp_config.json`; that is acceptable while `textGenerationModelSelection` uses Codex. New or reset T3 profiles are bridged only on the next Home Manager activation.

## Where

- `home/shell.nix` (`syncAntigravityConfig`, `home.activation.syncAntigravityConfig`, `home.file.".gemini/config"`)
