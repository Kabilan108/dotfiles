# Sessionizer caches git details by fingerprint and bounds every git and file read

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The picker preview and the `--inventory` listing show branch, dirty count, ahead/behind and last commit for many repositories. The inventory answers another host's picker inside a 15 second ssh timeout, and a cold cache on a host with many repositories can exceed that. git can leave helper processes (fsmonitor and similar) that hold its output pipe open. Directories can sit on slow or hung filesystems, and a README can be swapped for a FIFO or device after the directory listing.

## Decision

- `gitRepo` reads HEAD, index and refs straight from the `.git` directory without running git. `dir` holds HEAD and index; `common` holds refs, which differ for linked worktrees.
- `fingerprint` stats HEAD, index, the branch's ref file and the upstream's ref file (plus `packed-refs` when packed). It changes whenever a commit, checkout, stage or fetch could change what `git status` and `git log` report. Edits to tracked files show only once something refreshes the index, so cached details also expire after `gitCacheTTL` (10 minutes).
- A read whose `git log` failed or timed out (`complete` false) is kept so the preview shows it, but stamped as never read, so the next lookup runs git again.
- `gitCommand` runs git with `core.fsmonitor=false` and `--no-optional-locks` in its own process group, kills the group when the context ends and again once git exits, and waits at most `gitWaitDelay` (100 ms) for output after that.
- `summarizeDirectories` gives the inventory's git phase a `gitBudget` of 5 seconds. Repositories it skips are read on a later run.
- `gitCache.save` writes only this run's new entries over what is on disk, under a file lock shared with other processes, so pickers and inventories running at once keep each other's work.
- In the picker, `loadSelected` reads the selected directory off the update loop, shows cached git details as soon as the listing arrives, and schedules a fresh read after the cursor rests for `gitDebounce` (150 ms), so scrolling past repositories runs no git. The fresh read always runs because the cache cannot see unstaged edits. `freshGit` holds the latest read per row and wins over a summary that lands later.
- `readRegularHead` opens README files with `O_NONBLOCK|O_NOCTTY` and checks the type again on the open file, so a FIFO or device cannot hang the caller.

## Consequences

- Cached details can lag unstaged edits by up to 10 minutes in the inventory; the picker's settle-time reread covers local rows.
- An inventory can return directories without git details when the 5 second budget runs out.
- The cache file carries `gitCacheVer`; changing the entry format needs a version bump.

## Where

- `packages/sessionizer/git.go` (`gitRepo`, `fingerprint`, `gitCacheTTL`, `gitWaitDelay`, `gitCommand`, `gitResult`, `gitCache.reread`, `gitCache.save`)
- `packages/sessionizer/dirs.go` (`gitBudget`, `summarizeDirectories`, `readRegularHead`)
- `packages/sessionizer/picker.go` (`gitDebounce`, `loadSelected`, `freshGit`)
