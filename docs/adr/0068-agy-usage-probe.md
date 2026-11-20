# The agy usage probe ignores transient sign-in noise and pins its update flag

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The usage collector runs `agy -p /usage` and watches stderr for sign-in requests. agy briefly prints "not signed in" while it refreshes a valid login. Only "authentication required" and "waiting for authentication" mean agy is blocked on a browser login. agy reads `AGY_CLI_DISABLE_AUTO_UPDATE` only when it is the literal string `true`; other spellings, including `1`, are ignored.

## Decision

- `ANTIGRAVITY_LOGIN_PROMPT_MARKERS` holds only the blocking-prompt markers; a running probe stops early only on those. `ANTIGRAVITY_SIGN_IN_MARKERS` adds the broader markers for classifying a finished run.
- The probe environment sets `AGY_CLI_DISABLE_AUTO_UPDATE=true`.

## Consequences

A probe never aborts during a token refresh. If agy changes its prompt wording or its accepted spelling for the update flag, these constants must follow.

## Where

- `packages/stillsuit-shell/bin/stillsuit-agent-usage` (`ANTIGRAVITY_LOGIN_PROMPT_MARKERS`, `ANTIGRAVITY_SIGN_IN_MARKERS`, the probe environment builder)
