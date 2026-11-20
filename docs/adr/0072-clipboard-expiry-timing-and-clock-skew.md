# Clipboard expiry batches wakes and clamps future timestamps

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Entries expire `ttlHours` after last use. Waking for each entry's exact expiry
would wake the shell often, and copies keep arriving. Timestamps on disk can
come from a clock that ran ahead.

## Decision

The expiry timer interval stays between `MIN_TIMER_MS` (10 minutes) and
`MAX_TIMER_MS` (6 hours) with up to 5 s of jitter, so pruning batches expiries.
Commits only ever pull the wake earlier; restarting it on each commit would
starve it while copies keep arriving. A timestamp later than now is clamped to
now, so it can neither postpone expiry nor make a later clear look like it
came first.

## Consequences

An entry can outlive its TTL by up to 10 minutes.

## Where

- `packages/stillsuit-shell/src/plugins/builtin/clipboard/ClipboardModel.js` (`MIN_TIMER_MS`, `MAX_TIMER_MS`, `MAX_JITTER_MS`, `_time`)
- `packages/stillsuit-shell/src/plugins/builtin/clipboard/Service.qml` (`_rearm`)
