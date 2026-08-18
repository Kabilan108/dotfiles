---
name: review-swarm
description: "Parallel read-only multi-agent review of a current git diff or explicit file scope to find behavioral regressions, security or privacy risks, performance or reliability issues, and contract or test coverage gaps. Use when the user asks for a review swarm, parallel review, diff review, regression review, security review, or wants high-signal issues plus a prioritized fix path without editing files."
---

# Review Swarm

Review a diff with four read-only sub-agents in parallel, then have the main agent filter, order, and summarize only the issues that matter. This skill is review-only: sub-agents do not edit files, and the main agent does not apply fixes as part of this workflow.

## Step 1: Determine Scope and Intent

Prefer this scope order:

1. Files or paths explicitly named by the user
2. Current git changes
3. An explicit branch, commit, or PR diff requested by the user
4. Most recently modified tracked files, only if the user asked for a review and there is no clearer diff

If there is no clear review scope, stop and say so briefly.

When using git changes, choose the smallest correct diff command:

- unstaged work: `git diff`
- staged work: `git diff --cached`
- mixed staged and unstaged work: review both
- explicit branch or commit comparison: use exactly what the user requested

If the scope includes untracked files or a newly scaffolded project, `git diff` may be empty. Build the scope from `git status --short`, `git ls-files --others --exclude-standard`, and explicit file reads; tell reviewers which untracked files are in scope and which generated/vendor/build outputs are excluded.

Before launching reviewers, read the closest local instructions and any relevant project docs for the touched area:

- root and nearest `AGENTS.md` (or equivalent agent instructions)
- any `REVIEW.md` files from the repo root down to each reviewed path, root-to-leaf
- repo workflow docs and architecture or contract docs for the touched module

Include only the relevant guidance in the reviewer packet, and mention which guidance files were loaded in the final response.

Build a short intent packet for the reviewers:

1. What behavior is meant to change
2. What behavior should remain unchanged
3. Any stated or inferred constraints, such as compatibility, rollout, security, or migration expectations

If the user did not state the intent clearly, infer it from the diff and say that the inference may be incomplete.

## Step 2: Launch Four Read-Only Reviewers in Parallel

Default to four role-based reviewers for substantial single-repo diffs. Adapt the shape when the request calls for it, and say briefly why the shape differs:

- one isolated reviewer: a single read-only sub-agent carrying the full intent packet and the most relevant lenses
- multi-repo or linked-PR review: one reviewer per repo/PR, then cross-repo synthesis in the main agent
- tiny diff: review locally, or use one reviewer if the user explicitly asked for isolation

Harness notes: use whatever sub-agent mechanism the current environment provides. In Codex, if a full-history fork rejects custom `agent_type`/`model`/`reasoning_effort`, retry with inherited fork settings or a self-contained prompt. In Claude Code, use the Agent tool with the same scope, intent packet, read-only constraint, and role lens. If no sub-agent mechanism is available, review locally and say parallel review was unavailable.

For every sub-agent:

- give the same scope and the same intent packet
- state that the sub-agent is read-only, and enforce it at the tool/sandbox level when the harness supports it (e.g. `codex exec --sandbox read-only`, read-only agent types) — prose alone does not prevent mutation
- do not let the sub-agent edit files, run `apply_patch`, run formatters that write, stage changes, commit, or perform any other state-mutating action
- tell the sub-agent that tests/commands are allowed only if they are read-only in this environment; otherwise inspect code and report that validation was not run
- ask for concise findings only
- ask for: file and line or symbol, issue, why it matters, recommended follow-up, and confidence
- tell the sub-agent to avoid nits, style preferences, and speculative concerns without concrete impact
- tell the sub-agent to send findings back to the main agent only

Use these four review roles.

### Sub-Agent 1: Intent and Regression Review

Review whether the diff matches the intended behavior change without introducing extra behavior drift.

Check for:

1. Unintended behavior changes outside the stated scope
2. Broken edge cases or fallback paths
3. Contract drift between callers and callees
4. Missing updates to adjacent flows that should change together

This sub-agent is read-only. It must not edit files, apply patches, or make any other workspace changes.

Recommended sub-agent role: `reviewer`

### Sub-Agent 2: Security and Privacy Review

Review the diff for security regressions, privacy risks, and trust-boundary mistakes.

Check for:

1. Missing or weakened authn or authz checks
2. Unsafe input handling, injection risks, or validation gaps
3. Secret, token, or sensitive data exposure
4. Risky defaults, permission expansion, or trust of unverified data

This sub-agent is read-only. It must not edit files, apply patches, or make any other workspace changes.

Recommended sub-agent role: `reviewer`

### Sub-Agent 3: Performance and Reliability Review

Review the diff for new cost, fragility, or operational risk.

Check for:

1. Duplicate work, redundant I/O, or unnecessary recomputation
2. Added work on startup, render, request, or other hot paths
3. Leaks, missing cleanup, retry storms, or subscription drift
4. Ordering, race, or failure-handling problems that make the change brittle

This sub-agent is read-only. It must not edit files, apply patches, or make any other workspace changes.

Recommended sub-agent role: `reviewer`

### Sub-Agent 4: Contracts and Coverage Review

Review the diff for compatibility gaps and missing safety nets.

Check for:

1. API, schema, type, config, or feature-flag mismatches
2. Migration or backward-compatibility fallout
3. Missing or weak tests for the changed behavior
4. Missing logs, metrics, assertions, or error paths that make regressions harder to detect

This sub-agent is read-only. It must not edit files, apply patches, or make any other workspace changes.

Recommended sub-agent role: `reviewer`

Report only issues that materially affect correctness, security, privacy, reliability, compatibility, or confidence in the change. It is better to miss a nit than to bury the user in low-value noise.

## Step 3: Aggregate and Filter Findings

The main agent owns synthesis. Treat sub-agent output as raw review input, not final output.

First check `git status --short` against the pre-review state. If a sub-agent changed anything despite the read-only contract, report it and inspect the diff before trusting that agent's findings.

Merge findings across all four reviewers and filter aggressively:

- drop duplicates
- drop weak or speculative claims
- drop issues that conflict with the stated intent
- drop minor style or readability comments unless they hide a real bug or maintenance risk

Normalize surviving findings into this shape:

1. File and line or nearest symbol
2. Category: regression, security, reliability, or contracts
3. Severity: high, medium, or low
4. Why it matters
5. Recommended fix or follow-up
6. Confidence: high, medium, or low

If a reviewer may be correct but the intent is unclear, turn it into an open question instead of a finding.

## Step 4: Order the Output

Present findings in this order:

1. High-severity, high-confidence issues
2. Medium-severity issues that are likely worth fixing before merge
3. Lower-severity issues or follow-ups that can wait

Keep the review concise. Findings should be actionable and evidence-backed. Verify each surviving finding's cited file/line or symbol in the main agent before presenting it; if a finding depends on runtime data or external metadata you haven't inspected, downgrade it to an open question.

If there are no material issues, say that directly instead of manufacturing feedback.

## Step 5: Recommend a Clear Path Forward

After the findings, give the user a short path forward:

- what to fix before merge
- what to improve if time permits
- what can safely be left alone

When helpful, group the path forward into:

- `fix now`
- `fix soon`
- `optional follow-up`

Do not implement fixes as part of this skill. The output is a read-only review plus a prioritized recommendation. If the user also asked to fix true positives, finish and summarize the review first, then start a separate implementation phase in the main agent; after fixes, run validation and optionally a fresh read-only re-review pass.
