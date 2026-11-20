# Launcher usage boost follows Elephant's formula

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

App results should favour what the user launches often for a given query.
Elephant (abenz1267/elephant, GPL-3.0) already has a tuned formula,
`CalcUsageScore` in `pkg/common/history/history.go`, and its
desktopapplications provider gates the boost with `min_score 30`.

## Decision

`History.js` reimplements Elephant's usage formula with two differences:
related stored queries contribute their best per-record boost instead of a
summed count, and the length difference divides as `(1 + delta)`, so results
do not depend on map iteration order. The apps provider uses Elephant's field
order and `MIN_SCORE = 30` to gate the boost.

Boost tables are rebuilt once `TABLE_MAX_AGE_MS` (60 s) has passed, so a cached
table never drifts by more than a fraction of a day. `boost` runs once per
matching candidate per keystroke, so it compares the raw query before
normalising it again. Records stamped more than `MAX_FUTURE_MS` (one day)
ahead are dropped on load; nearer future stamps from clock skew rank as now.
The empty-query recency tie-breaker stays below `TIE_BREAK_MAX` (0.5) and
ranks are integers, so recency only orders equal ranks.

## Consequences

The formula and its constants are reimplemented, not copied, so Elephant's
licence places no obligation on `History.js`, and the credit is a courtesy.
Copying Elephant code would still be allowed. This repo is AGPL-3.0, and
section 13 of GPL-3.0 and of AGPL-3.0 permits combining the two. Copied code
would need to keep Elephant's copyright notice in the file that holds it, and
`scripts/comment-lint.baseline.json` would need an entry for that notice.

## Where

- `packages/stillsuit-shell/src/plugins/builtin/launcher/model/History.js` (`TABLE_MAX_AGE_MS`, `MAX_FUTURE_MS`, `TIE_BREAK_MAX`, `history.boost`)
- `packages/stillsuit-shell/src/plugins/builtin/launcher/model/providers/apps.js` (`MIN_SCORE`)
