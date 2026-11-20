# obsidian-reconcile re-syncs externally written vault files on a best-effort basis

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Obsidian's file watcher misses some external writes (a mount/inotify race). Missed files stay out of `metadataCache`, so task queries and TaskNotes do not see them. A fresh Obsidian launch scans the whole vault and needs no help.

## Decision

`obsidian-reconcile <path>...` (absolute or vault-relative) calls `reconcileFile()` through obsidian-cli for each path. That handles creation, modification and deletion without a full vault reload. It exits 0 when obsidian-cli or a running vault is absent, so callers fire and forget (`tracer-digest` calls it with `|| true`).

## Consequences

A failed reconcile is silent. If Obsidian fixes its watcher, the script and its callers can go.

## Where

- `bin/obsidian-reconcile`
- `bin/tracer-digest` (caller)
