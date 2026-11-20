# Keep the Python picker's inventory and favorites formats

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Sessionizer was a Python script driving fzf until the Go rewrite on 2026-11-08. Fleet hosts rebuild at different times, so a Go picker can talk to a host still running the Python inventory, and the reverse. The Python picker read `id`, `name`, `windows`, `attached`, `activity` and `path` from each inventory session, with `windows` and `attached` as strings. Its favorites file used `session:<host>:<name>` and `path:<host>:<path>` keys.

## Decision

- The inventory keeps those six fields and still writes `windows` and `attached` as strings. `flexString` reads either strings or numbers.
- `inventorySession` folds `last_attached` into `activity`, and `InventorySession.Recency` falls back to `activity` when an older host sends neither `last_attached` nor `created`. It otherwise matches `tmuxSession.Recency`.
- `favoriteKey` keeps the Python picker's key format, so `favorites.json` carries over.

## Consequences

- New inventory fields must be optional (`omitempty`), and the preview says a host "may run an older sessionizer" when pane details or listings are missing.
- Once every host runs the Go build, the string encoding and the `activity` fallback can go; the favorites key format stays unless favorites are migrated.

## Where

- `packages/sessionizer/inventory.go` (`Inventory`, `InventorySession.Recency`, `flexString`)
- `packages/sessionizer/rows.go` (`Row.favoriteKey`)
