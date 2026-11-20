# Host refreshes never move rows in an open picker

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The picker opens with cached remote inventories and refreshes each host in the background. A refresh that re-sorted the list would move rows under the cursor while the user is choosing.

## Decision

- `mergeHostRows` folds a host's fresh rows into the open list without moving rows already shown. Rows the host no longer has drop out, except the current row, which can be newer than a cached inventory, and the selected row, so a refresh never moves the cursor. New sessions go after the last session and new directories at the end.
- Sections are grouped from row order at filter time, so a favorite appended by a refresh still shows under FAVORITES.
- `markVisited` bumps a remote session's cached `last_attached` and `activity` to now when the picker opens it, so the next picker orders it correctly before that host's refresh lands.

## Consequences

- Within one open picker, rows added by a refresh are not in recency order with the rest; the next picker sorts them.

## Where

- `packages/sessionizer/rows.go` (`hostRank.mergeHostRows`)
- `packages/sessionizer/picker.go` (`refilter`)
- `packages/sessionizer/fleet.go` (`markVisited`)
- `packages/sessionizer/picker_test.go` (`TestSectionsAndCursorSkipHeaders`)
