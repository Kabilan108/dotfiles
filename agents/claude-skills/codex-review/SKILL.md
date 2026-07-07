---
name: codex-review
description: Ask Codex CLI (gpt-5.5) for an independent code review of uncommitted changes, a branch diff, a commit, or a specific implementation. Use when the user asks for Codex or gpt-5.5 review work, when the model-selection rubric calls for a gpt-5.5 review perspective, or when Codex should audit a diff, find bugs or regressions, or compare an implementation against requirements. For a review by the current agent itself, use the normal review process instead.
---

# Codex Review

Use Codex as an independent second-opinion reviewer. Per the model rubric, primary reviews belong to fable or opus (`/code-review`, `review-swarm`); this skill adds the gpt-5.5 perspective on top of those, or handles the case where the user explicitly asks for a Codex review.

Prefer the current agent's normal review process for small local checks. Do not delegate every lint, type, or formatting issue to Codex.

## Workflow

1. Identify the review target: uncommitted changes, base branch, commit SHA, PR checkout, or specific files.
2. Create a temporary artifact directory for the Codex report and log.
3. Run Codex review with a focused review prompt.
4. Read Codex's report and verify important claims against the code before presenting them.

`codex exec review` has no `-C` flag — run it from the repository being reviewed. Reviews are read-only and quality matters, so run them at `xhigh` effort.

```bash
ARTIFACT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-review.XXXXXX")"
REPORT="$ARTIFACT_DIR/report.md"
PROMPT="$ARTIFACT_DIR/prompt.md"
LOG="$ARTIFACT_DIR/codex.log"
```

Review staged, unstaged, and untracked changes:

```bash
codex exec review -c model_reasoning_effort=xhigh --uncommitted \
  -o "$REPORT" - < "$PROMPT" > "$LOG" 2>&1
```

Review current branch against a base branch:

```bash
codex exec review -c model_reasoning_effort=xhigh --base <branch> \
  -o "$REPORT" - < "$PROMPT" > "$LOG" 2>&1
```

Review a single commit:

```bash
codex exec review -c model_reasoning_effort=xhigh --commit <sha> \
  -o "$REPORT" - < "$PROMPT" > "$LOG" 2>&1
```

`xhigh` reviews take a while — launch via Bash `run_in_background`; the findings land in `$REPORT` via `-o`.

## Review Prompt

Ask Codex to use a code-review stance:

```text
Review these changes for bugs, regressions, missing tests, security issues, and requirement mismatches.

Prioritize findings over summary. For each finding include:
- severity
- file and line reference
- concrete failure mode
- suggested fix direction

Do not edit files. If there are no substantive findings, say so and name any residual test gaps.
```

Add task-specific context when useful: requirements, risky areas, expected behavior, relevant tests, or files the current agent is unsure about.

## Follow-ups

To ask Codex to elaborate on a finding or re-check after a fix, resume its session. Codex prints a `session id:` line in its output frontmatter — resuming by id keeps follow-ups pinned to this run even if other Codex sessions ran in between:

```bash
SESSION_ID="$(sed -n 's/^session id: //p' "$LOG" | head -1)"
codex exec resume "$SESSION_ID" -o "$REPORT" "<question or re-check request>"
```

## Reporting Back

Before relaying a Codex finding, inspect the cited code or diff enough to decide whether the finding is real. In the user-facing response, separate confirmed issues from Codex suggestions you did not verify.

If Codex finds nothing, say that clearly and mention what review target it inspected.

If `codex` is not installed or the command fails, report the error and offer to review the changes directly instead.
