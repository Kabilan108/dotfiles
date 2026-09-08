---
name: claude-review
description: Consult Fable 5.1 for a requested Claude second opinion on code, APIs, or design.
---

# claude-review

Use this entrypoint for the requested cross-provider perspective. The lead remains responsible for adjudication and integration. Target Fable 5.1 at medium unless the user specifies otherwise.

Write a prompt file with the repository, exact diff/commit or proposal, intended behavior, accepted decisions, relevant environment, verification already performed, and review-only scope. Ask for actionable defects or design concerns with severity, locations, impact and evidence. For behavioral probes, include the relevant instructions from `~/dotfiles/agents/references/empirical-review.md` in the worker's context.

```sh
agent-run start --provider claude --model claude-fable-5-1 --effort medium --access default --repo /absolute/repo --prompt /absolute/review.txt
```

Run `agent-run --help` for lifecycle details. Immediately attach a managed wait as described in your global instructions. Read-only intent belongs in the prompt; the provider's access mode is separate. Claude's default permission mode preserves its configured policy and is not a read-only sandbox. Do not silently bypass permissions for a review.

Read the actual result and check the findings against source. Fix in-scope true positives only when implementation is authorized. For a follow-up, use `agent-run start --resume-from <run-id> --prompt <followup-file>` to preserve the provider session, model, effort and access choices. Re-review only affected behavior when useful. A failed run or missing report is not a clean review.
