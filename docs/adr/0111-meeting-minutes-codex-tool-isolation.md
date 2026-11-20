# Meeting-minutes Codex runs expose only a fixed, harmless tool set

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Every Codex run in the pipeline reads meeting content from outside the vault: transcripts, Slack, email, Meet notes and calendar text. None may hold a tool that acts on the world. `docs/meeting-minutes.md` (Isolation) describes the pipeline-owned `CODEX_HOME`, the workspace outside `$HOME` (Codex reads `.codex/config.toml` from every parent of its working directory, and `~/.codex` is one), and the shared login and lock.

Codex 0.166 keeps `unified_exec` on whatever the config says. With `shell_tool` off it exposes no command tool.

## Decision

`CODEX_EXPECTED_TOOLS` lists exactly what Codex 0.166 offers under the pipeline's config, and each process checks it before sending meeting content. The remaining tools are judged harmless:

- `exec` runs JavaScript in an isolate with no file system or network, and can call only the nested tools in the list.
- `apply_patch` is refused by the read-only sandbox with approvals off.
- The MCP resource readers have no servers configured.
- A clock.

Anything else, such as an MCP namespace or sub-agents, fails the run.

## Consequences

A Codex upgrade that changes its built-in tools fails closed. Review the new tool list against the reasoning above before updating `CODEX_EXPECTED_TOOLS`.

## Where

- `bin/meeting-minutes` (`CODEX_HOME_DIR`, `CODEX_WORKSPACE`, `CODEX_EXPECTED_TOOLS`)
- `docs/meeting-minutes.md` (Isolation)
