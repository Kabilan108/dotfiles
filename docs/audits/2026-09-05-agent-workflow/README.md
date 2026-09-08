# Agent workflow audit — reading guide

The audit and refinement pass ran September 5–8, 2026. The reviewed skill, helper, and global instruction files define current behavior. These audit documents are records, not an additional instruction layer.

## Current entrypoints

- [Fable follow-up](fable-follow-up.md): implemented corrections, live validation, limitations, and the ordinary-use observation plan.
- [Prompt quick reference](prompt-quick-reference.md): optional phrases for Tony, not global agent rules.
- [Moberg follow-up](moberg-follow-up.md): deferred project-specific rollout and acceptance criteria.
- Source: `agents/skills/`, harness-specific skill roots, `agents/claude/CLAUDE.md`, `agents/codex/AGENTS.md`, and the helpers in `bin/`.

## Retained history

- [Initial audit](audit.md), [inventory](inventory.md), and [prompt proposals](proposed-prompts.md): initial assessment and options; superseded by later review choices.
- [Review decisions](review-decisions.md) and [change plan](change-plan.md): intermediate decisions; subsequent user edits and Fable corrections take precedence.
- [Implementation review](implementation-review.md): September 7 snapshot, not the final invocation or validation matrix.
- [Evidence](evidence.md), [delegation wakeups](delegation-wakeups.md), and [usage data](usage.json): dated observations and sampling limits. Preserve these rather than rewriting past observations to match today's configuration. Links to retired skill paths are historical.

Latest polish: HTML verification wording was shortened by Tony; the globals now prefer dev servers on the server host's Tailscale IP unless project configuration says otherwise. No networking changes or activation were performed by this documentation pass.
