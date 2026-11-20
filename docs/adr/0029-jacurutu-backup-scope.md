# jacurutu backs up authored work and skips data that can be fetched again

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

jacurutu's Restic `files` job covers notes, media, project trees, browser profiles and Moberg data. The other Moberg data trees are recoverable from COS. Project trees hold regenerable dependency and cache directories and vendored dependency clones, and a branch or worktree can share a name with a dependency directory.

## Decision

- Only `/vault/moberg-data/backups` and `/vault/moberg-data/projects` are backed up from the Moberg data.
- Dependency and cache exclusions apply only under the project roots. Git metadata, nested source checkouts and local or ignored data stay in.
- `!<root>/**/.git/**` re-includes Git directories that an exclusion name would otherwise match.
- Named vendored clones fetched by projects (zed, t3code, terragon-oss and the jupyter-ai vendors) are excluded.

## Consequences

A new vendored clone must be listed by hand. A Moberg tree that stops being recoverable from COS must be added to the paths.

## Where

- `machines/jacurutu/default.nix` (`projectBackupExcludes`, `dotfiles.backup.jobs.files`)
