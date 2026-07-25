---
name: adversarial-probe-review
description: Spawn an empirical adversarial reviewer — a Claude subagent permitted to build and run probe scripts under /tmp against the real code — to attack a diff's specific invariants and convert plausible findings into CONFIRMED ones. Use at review checkpoints for correctness-critical changes (concurrency, GC/retention, auth/capability surfaces, parsers, state machines), standalone or as the Claude-reviewer leg of the milestone delegation loop.
---

# Adversarial Probe Review

A static reviewer says "this looks racy"; a probe reviewer stalls two request bodies, interleaves the writes, and shows you the lost update. An empirically confirmed bug is worth ten plausible ones — and a probe that fails to reproduce a suspicion kills a false positive before it wastes a fix cycle.

## When to use

Correctness-critical diffs where failure modes are behavioral, not stylistic: CAS/concurrency, garbage collection and retention, capability/auth surfaces, parsers over untrusted input, cache/dedupe logic. Not worth the tokens for UI copy or mechanical refactors. Runs well in parallel with a static review (codex-review); the two catch disjoint bug classes.

## Spawning the reviewer

Use the Agent tool (general-purpose, background). The prompt must be self-contained. Template — fill every slot; the invariant list is the load-bearing part, so derive it from the diff's actual claims, one numbered item per invariant, each with concrete attack suggestions:

```text
You are an adversarial code reviewer with permission to build and run empirical
probes. Repo: <path>, branch <branch>. The change under review is <diff scope,
e.g. "the UNCOMMITTED working-tree diff vs HEAD (git diff)">. Your job is to find
real defects and CONFIRM them empirically where possible — an empirically
confirmed bug is worth ten plausible ones. Do not summarize the change.

Context: <2-4 sentences: what the system is, what the diff adds, key files.>

Environment notes:
- <How to run commands so deps resolve (direnv, nix shell, etc.).>
- WARNING when applicable: <the ambient env exports real credentials/endpoints —
  probes must always pass explicit overrides and never print those values.>
- <Where existing tests show how to drive the code in-process with stubs —
  reuse that pattern for probes.>
- Build probe scripts under /tmp (e.g. /tmp/probe-*.ts). You may manipulate stub
  state, fake clocks/timers, and stall request bodies to force interleavings.
- READ-ONLY with respect to the repo: do not modify any file inside <path>.

Attack these invariants, empirically where feasible:
1. <Invariant + concrete interleavings/inputs to try>
2. <...>
   Typical domains: CAS/concurrency interleavings; GC/retention (age objects
   past grace, then sweep); auth/capability revocation across every route
   shape; input fuzzing on new parsers ("01", "1e3", "+1", "-1", "0", huge,
   empty, encoded); secret/internal-field leakage in any response; origin/host
   gating; dedupe false-positives and false-negatives; CLI argument edges.

Deliverable (this is your final message; raw findings, no pleasantries):
numbered findings ranked by severity, each with file:line, a concrete failure
scenario, whether you CONFIRMED it empirically (include the probe command and
output essence) or it remains PLAUSIBLE, and a suggested fix direction. Include
a table of probes run with their outcomes. Say "no finding" per attacked
category that came up clean. End with a one-paragraph ship/no-ship verdict.
```

## Adjudicating the results

- Reviewer conflicts (against a parallel static review) are settled by reading the source or running the probe yourself — never by majority vote.
- Accept only findings with a concrete failure scenario; a CONFIRMED finding with probe output is fix-now.
- Log every declined finding with a one-line rationale (deployment reality, cost/benefit, inherited behavior) — in the PR body if one exists.
- A finding can be real but unreachable in your deployment topology; say so explicitly rather than silently dropping it.
