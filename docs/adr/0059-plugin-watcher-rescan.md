# Plugin watcher keys rescans on every scan input, including rejected symlinks

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

`stillsuit-plugins watch` rescans only when the stat key (inode, size, mtime, ctime) of a scan input or published generation changes. `scan()` follows a symlinked plugin folder far enough to read its manifest ID before rejecting it, so that ID claims its place in root precedence. A scan can also fail partway.

## Decision

- `tree_keys` adds stat keys for a symlinked entry and its `manifest.json`, so changing either triggers a rescan.
- `Watcher.poll` sets `self.inputs = None` before scanning. A scan that raises leaves it unset, and the next poll scans again even if nothing changed.

## Consequences

A failing scan retries about once a second until it succeeds. Dropping the symlink keys would let a symlinked plugin's manifest change go unnoticed while it still holds its ID.

## Where

- `packages/stillsuit-shell/bin/stillsuit-plugins` (`tree_keys`, `Watcher.poll`)
