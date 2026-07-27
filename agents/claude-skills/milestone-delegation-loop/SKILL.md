---
name: milestone-delegation-loop
description: Orchestrate a multi-milestone implementation with delegated coding and adversarial review checkpoints. Use when an approved plan should be executed phase-by-phase with codex implementing and paired reviewers gating each commit, or when asked to "run the milestone loop" on a plan.
---

# Milestone Delegation Loop

Composes codex-implementation, codex-review, and html-plans into a per-milestone
loop. Proven shape: cheap delegated implementation, expensive independent
review, lead adjudication, one commit per milestone.

## Per milestone

1. **Implement** — delegate to codex (see codex-implementation for mechanics;
   long runs go in detached tmux so they survive harness restarts). tmux exits
   fire NO notification: immediately after launching, arm a harness-tracked
   watcher (`run_in_background` Bash until-loop that exits when the `-o`
   report file appears OR the tmux session dies) — the loop orchestrator has
   stalled overnight on a completed run because this watcher wasn't armed.
   After any harness/session restart, re-check every in-flight run and re-arm
   watchers (tmux survives the restart; watchers don't). When invoking
   `codex exec` outside tmux, always redirect `< /dev/null` — with an
   inherited non-tty stdin it blocks on "Reading additional input from
   stdin..." before doing any work. Check liveness by process/tmux session,
   never by "output file exists yet". Pick effort by the work's shape:
   - `medium` for well-specced work — the default, even when it looks mechanical
   - `high` for larger or open-ended changesets
   - `low` only for genuinely trivial grunt work; low reliably misses subtle
     correctness classes (parsers over untrusted text, concurrency, security
     surfaces)
2. **Verify yourself** before any review: fmt/lint/tests with exit codes
   checked directly (never piped through filters that mask failure).
3. **Checkpoint** — two independent adversarial reviewers in parallel:
   - codex at `high` (read-only sandbox), prompted to attack specific
     invariants, not to summarize
   - a Claude reviewer (fable/opus at `high` effort) explicitly permitted to build probe
     binaries under /tmp and empirically confirm suspected bugs against the
     real binary — empirical confirmation converts "plausible" into "fix now"
4. **Adjudicate** — the lead resolves the union of findings:
   - Reviewer conflicts are settled by reading the source/stdlib directly,
     never by majority vote (reviewers have disagreed and BOTH been partially
     right).
   - Every accepted fix must trace to a concrete failure scenario.
   - Every declined finding is logged with a one-line rationale.
5. **Fix** — send the consolidated fix list back to the SAME codex session
   (`codex exec resume <session-id>`), escalating effort if the original tier
   produced the defects. Re-verify any reproduced bug against the rebuilt
   binary, not just the test suite.
6. **Commit** — one commit per milestone with a why-focused message.
7. **Log** — update the live implementation log (html-plans) with the
   checkpoint outcome and decisions BEFORE starting the next long-running
   step, so a session restart loses nothing.

## Ordering rules

- Ship infrastructure first (CI/release plumbing) so later milestones flow
  through it.
- Milestones that document the CLI surface (skill text, README passes) go
  last so they describe the final state.
- Cross-cutting artifacts (golden recordings, fixtures) get one consolidated
  pass at the end instead of churning per milestone.

## Failure modes this loop exists to catch

- Delegated implementations that pass their own tests but fail adversarial
  probing (fail-open parsers, injection via config values, shutdown races).
- Scope deviations by the implementer — evaluate against the plan's intent;
  a deviation can be correct (accept and log it) or drift (revert it).
- Documentation that contradicts the binary (drift-guard style tests catch
  this mechanically; reviewers catch the semantic version).
