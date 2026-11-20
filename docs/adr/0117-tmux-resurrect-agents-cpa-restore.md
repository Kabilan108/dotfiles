# tmux-resurrect-agents restores agents through their CPA wrappers

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

`claude-cpa` and `codex-cpa` (`modules/home/cpa-clients.nix`) put CPA settings in the agent's environment and then exec the real binary, so tmux-resurrect saves the binary's command line, not the wrapper. `codex-cpa` adds its own `-c model_provider="cpa"` override.

## Decision

- `uses_cpa` reads the agent process's `/proc/<pid>/environ` to tell whether a wrapper started it.
- `cpa_command` rewrites the saved command to `<agent>-cpa <args>`, dropping a leading `model_provider` override for Codex so the wrapper does not add it twice.
- The cleanup `trap` is double-quoted so the temp file paths expand when it is set, while the locals still exist (shellcheck SC2064 is disabled for that line).

## Consequences

If the wrappers change how they mark the environment or add other flags, `uses_cpa` and `cpa_command` need the same change.

## Where

- `bin/tmux-resurrect-agents` (`uses_cpa`, `cpa_command`, the cleanup trap)
- `modules/home/cpa-clients.nix`
