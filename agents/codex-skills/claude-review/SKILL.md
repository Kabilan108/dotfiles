---
name: claude-review
description: Run a trusted Claude CLI peer-review loop for code changes, feature APIs, and interface designs. Use when the user asks for Claude, claw-p, or claude -p review; requests an independent review of an API or interface proposed for a new feature or refactor; requests a code-review boundary; or wants findings triaged, fixed, and re-reviewed before proceeding.
---

# Claude review

Run Claude as a read-only reviewer either before implementation, when a feature API or interface design is concrete enough to evaluate, or after a coherent feature or subsystem is complete.

## Review

1. Verify the review scope and provide Claude the repository path, feature context, accepted design decisions, and relevant artifacts. For implementation reviews, include the intended diff and validation already performed. For design reviews, include the proposed API, interface, call sites, compatibility constraints, and migration or ownership boundaries.
2. For code, ask only for concrete behavioral regressions, security or privacy defects outside the accepted model, performance or reliability issues, and meaningful test gaps. For API or interface design, ask for concrete ambiguity, invalid states, compatibility hazards, leaky abstractions, missing lifecycle or error semantics, and adoption or migration risks. Require severity and precise references to files, symbols, or proposal sections.
3. When the user has explicitly trusted Claude, run:

   ```sh
   claude --dangerously-skip-permissions -p --output-format text "<review prompt>"
   ```

   Otherwise omit `--dangerously-skip-permissions` and honor the normal approval boundary.
4. Use a PTY for long reviews and poll until the process exits. Silence is not a clean review.

## Triage and close

- Inspect each finding against the code or design constraints. Address true positives and reject false positives with concrete reasoning.
- Re-run the relevant tests and static checks after code fixes. For design changes, update the proposal and its affected examples or interface sketches.
- Ask Claude to re-review only the changes made in response and confirm whether its findings are resolved.
- Report review infrastructure failures honestly. For approval timeouts, retry once; for restricted-network failures, request the appropriate permission rather than treating the review as successful.
- Never ask Claude to edit files during the review loop.
