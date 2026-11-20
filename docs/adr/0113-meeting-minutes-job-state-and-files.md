# Meeting-minutes job state, caches and media files survive crashes and reloads

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The meeting-minutes worker runs long jobs over large media files, can be killed at any point, and shares the media directory with a sync step that moves recordings to sietch. Generated results are cached per job. Home Manager's `~/media` link passes through `/nix/store`, and Codex's file handling cannot open its output file through that chain. Older notes linked from the weekly log use `[[meetings/<stem>|...]]` instead of `[[01-logs/meetings/<stem>|...]]`.

## Decision

- `GENERATION_VERSION` is bumped whenever a prompt or validation rule changes, so cached results regenerate.
- Before transcoding, the worker deletes `.<stem>.*.tmp.flac` files a SIGKILLed transcode left behind; they are hundreds of MB.
- Siren progress is written to both durable job state and the current-status projection, so a shell reload does not erase the visible stage.
- Codex's `--output-last-message` path is passed through `resolve()` to the real path.
- The weekly-log backlink check matches `meetings/<stem>|`, which also finds backlinks in the older form.
- Artifact sync takes the worker lock and then the sync lock, so publication and retries finish before sync snapshots job paths. It excludes each job's `canonical_stem` files as well as its recorded paths, because a crash can leave a rename durable before the job's path update.

## Consequences

Forgetting to bump `GENERATION_VERSION` serves stale cached minutes. The lock order (worker, then sync) must stay the same everywhere both are taken.

## Where

- `bin/meeting-minutes` (`GENERATION_VERSION`, the transcode temp cleanup, Siren phase reporting, the Codex output path, the weekly-log backlink check, artifact sync)
