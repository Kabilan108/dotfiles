---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: "What will the next session be used for?"
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work.

Save location:

- If the user names a file or directory, use it — durable project handoffs (e.g. a `docs/handoffs/` directory) are a valid ask.
- Otherwise save to the temporary directory of the user's OS with a descriptive filename — not the current workspace.

Before writing, gather objective state where relevant: `git status --short --branch` for each touched repo/worktree, recent commits, which verification commands passed/failed/were skipped, and any running processes, tmux sessions, remote hosts, or output paths that matter. Don't guess — if state can't be recovered, say so.

Suggested structure (adapt to the audience and destination):

- **Status** — current phase, what's done, the user's last direction
- **Start here** — ordered list of files/docs/commands the next agent should inspect first
- **Completed** — concrete changes, commits, validation evidence
- **Decisions and rationale** — settled choices, including rejected alternatives
- **Current state** — repos, branches, dirty/untracked files, processes, hosts, paths
- **Remaining work** — ordered next steps with enough detail to act
- **Risks and blockers** — failed commands, missing validation, "do not touch" notes
- **Suggested skills** — skills the next agent should invoke, with the concrete reason each applies

Do not duplicate content already captured in other artifacts (PRDs, plans, ADRs, issues, commits, diffs, prior handoffs). Reference them by path or URL and summarize only what the next agent needs to use them correctly.

Redact secrets and sensitive data: API keys, tokens, passwords, private keys, full connection strings, and unnecessary personal/customer/patient identifiers.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.

If there is no meaningful context to hand off, say so instead of writing a hollow file.
