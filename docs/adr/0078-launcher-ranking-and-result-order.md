# Launcher ranks rows with a quickselect cut and keeps provider order for strong matches

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Some providers have a natural order (recency for windows and clipboard, menu
order for power) that fuzzy scores would scramble. A full comparator sort of a
1,500-row result costs about 15,000 JS calls in V4, and V4's `Array.sort` is
not stable.

## Decision

Rows within `STRONG_MATCH_RATIO` (0.75) of the best score count as equally
good, so recency-ordered providers keep their own order and weaker matches
follow by score. The clipboard provider does not penalise the match start,
since where a match sits in a long clip says little about relevance. Power
rows add `items.length - index` so equal matches keep menu order.

`leadingRows` finds the cut-off score with a quickselect, sends only rows above
it through the comparator, groups rows tied on the cut-off by label and sorts
the labels natively. `rowsAt` breaks ties by input index because V4's sort is
not stable. It returns at least `limit` distinct keys, since duplicate keys
would leave the caller short.

The web fallback row is trailing: the engine appends it after every real match
and only when the result cap leaves a free slot.

A background refresh keeps the user's armed action: moving the action
selection sets `_userMoved`, and the armed action follows its id across
refreshes, falling back to the default when it disappears.

## Consequences

Providers that want their own order must produce it before scoring and rely on
the strong-match band. Replacing `leadingRows` with a plain sort is correct but
slower on large result sets.

## Where

- `packages/stillsuit-shell/src/plugins/builtin/launcher/model/Matcher.js` (`STRONG_MATCH_RATIO`)
- `packages/stillsuit-shell/src/plugins/builtin/launcher/model/Engine.js` (`leadingRows`, `rowsAt`)
- `packages/stillsuit-shell/src/plugins/builtin/launcher/model/providers/clipboard.js`, `packages/stillsuit-shell/src/plugins/builtin/launcher/model/providers/power.js`, `packages/stillsuit-shell/src/plugins/builtin/launcher/model/providers/web.js` (`FALLBACK_SCORE`)
- `packages/stillsuit-shell/src/plugins/builtin/launcher/Service.qml` (`cycleAction`, `_userMoved`)
