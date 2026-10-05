---
name: review-loop
description: Review loop for a committed change.
---

# Review loop

You are the lead: the reviewer finds, you adjudicate and fix. The loop has **converged** when the reviewer reports "No remaining findings" on the current head. It runs the same on a local branch, a pushed branch or an open PR, and it ends at convergence.

## Reviewer

GPT 6.1 Sol at high effort, launched with the T3 `delegate_task` tool:

```json
{
  "target": {"providerInstanceId": "codex", "model": "gpt-6.1-sol", "options": {"reasoningEffort": "high"}},
  "role": "review",
  "mode": "async",
  "title": "<repo> review r<k>",
  "clientRequestId": "<repo>-<change>-review-r<k>",
  "task": "<prompt from the template below>"
}
```

Keep any model or effort the user names. Each round is a new `delegate_task` call with its own `clientRequestId`. The reviewer starts every round with no memory, so the prompt carries the whole history. The result arrives as a notification: end the turn, then read it with `task_status`. Outside T3, launch the same prompt through `agent-run` (see `agent-run --help`).

## Steps

1. **Freeze the head.** Commit the change and leave the tree clean. Record the base and head SHAs, the intended behaviour, the decisions already settled with the user, and the verification already run. Done when `git diff <base>..<head>` shows exactly what will ship.

2. **Run round k.** Fill in the prompt template, launch the reviewer, and wait for the notification. Done when a report with a verdict line has arrived for the current head. A failed run, a missing report, or a report on an older head is not a round.

3. **Adjudicate every finding** against the source. Trace or reproduce it yourself before acting on it. Give each finding one verdict:
   - **Fixed:** the fix, plus a regression test that fails on the previous head.
   - **Rejected:** the evidence (code path, test, measurement) showing the scenario cannot happen or is intended.
   - **Deferred:** real, but outside this change. It goes in the log for the human reviewers.

   Done when every finding has a verdict and its evidence.

4. **Advance the head.** Commit the fixes, rerun the repository's own checks with their exit codes captured, record the new head, and start round k+1 at step 2. The loop has converged when a round on the current head reports no remaining findings. A clean round on an earlier head does not count.

   Escalate to the user, and stop looping, when a finding stays disputed after two rebuttals, a fix needs a decision outside the settled design, or round 5 still has findings.

5. **Write the review log.** For each round: its head SHA, the findings, their verdicts and evidence. Then the disputes and how they ended, and the final verdict. Keep it short enough to paste into a PR description or a reply to human reviewers. Done when the log accounts for every finding from every round.

For a consequential behavioural invariant (concurrency, retention, authorization, untrusted input, cache identity, lifecycle), add the method in `~/dotfiles/agents/references/empirical-review.md` to the prompt.

## Prompt template

Settled decisions and earlier verdicts keep the reviewer judging the execution instead of reopening choices the user already made. The environment section names the reviewer's read scope and commands; without one, Sol roams.

```markdown
You are reviewing <change> in <repo>, round <k>. Checkout: <path>, branch <branch>, head <sha>, base <sha>. Review `git diff <base>..<head>`. This is a read-only review: report findings and leave files, commits, branches and remote state as they are.

## Intended behaviour
<what the change does and why>

## Settled decisions
<design choices made with the user, and accepted limitations>

## Verification already run
<checks and their results>

## Earlier rounds
<round 2 onward: each finding, its verdict (fixed in <sha>, rejected, or deferred), and the evidence>
Confirm each fix. Contest a rejection only with a new concrete scenario.

## Environment
<how to build and test here; the paths you may read; where scratch files go; limits on I/O or long-running commands>

## Output
Findings, most severe first. For each: file:line, the defect in one sentence, a concrete failure scenario (input, then wrong result), a suggested fix, and CONFIRMED (reproduced or fully traced) or PLAUSIBLE. Report style issues only when they hide a bug. End with exactly one line: "No remaining findings" or "N findings".
```
