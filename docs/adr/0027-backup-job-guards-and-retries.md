# Backup jobs fail fast, count their own retries and are watched from another host

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Restic backs up each host to its own SMB share on the NAS. Several defaults would turn an outage into a silent or endless failure:

- A burst of failed mounts during a NAS outage trips the mount unit's start limit. The automount stays failed and the share's path is an empty local directory until something resets it.
- When the repository is missing, restic keeps retrying its config with backoff for many minutes per attempt.
- restic treats `--files-from` entries as patterns and silently skips one that matches nothing, so a moved source would back up nothing.
- systemd's `Restart=` start limit is a time window. Slow attempts (a lock wait, a long upload) outlast it, so the job would retry forever without alerting.
- Without a terminal, restic reports nothing until it ends.
- A NixOS switch briefly drops `/etc/zoneinfo`. A local-time timer recalculated in that gap can fire early.
- A copy made with SQLite's `.backup` inherits the source's WAL mode.
- A laptop that is offline can't alert that its own backups stopped.

## Decision

- The state directory `/var/lib/backup` is 0700 root, and the NAS mounts beneath it, so ordinary users can't trigger or browse the automount.
- The share is an `x-systemd.automount` with `nofail`, a 600 s idle timeout and a 30 s mount timeout. A laptop away from the NAS fails the run instead of writing into an empty local directory.
- Every run first resets the failed mount and automount and starts the automount again, then fails within seconds unless `<repository>/config` exists. It also refuses to run while the Restic password still holds the placeholder.
- `backupPrepareCommand` fails when any configured source path is missing.
- `progressFps` is 1/60: one progress line a minute in the journal.
- `backup-retry` runs in `ExecStopPost` and counts failed attempts in `/run/backup-retry/<job>`, however long each took. With retries left (default 3) it schedules the next attempt with a `systemd-run` timer after `delaySec` (default 900 s). The last failure alerts once and resets the count. A success resets the count and stops any pending retry timer, which would otherwise run the job again.
- Units in `stopUnits` start again from `backupCleanupCommand`, which is `ExecStopPost`, so they come back after a failed snapshot too.
- Timers use UTC: jobs at 09:00, the check on the 8th at 08:00, the staleness check at 17:00.
- `backup-capture` sets `journal_mode=DELETE` on each SQLite copy, so it is one self-contained file.
- Hosts that receive other hosts' status files run `backup-stale-check` daily and alert once per stale job or silent host. A host that sends its status nowhere can check its own jobs (`staleness.ownJobs`).

## Consequences

- An outage produces one alert after the retry budget, not a loop.
- The guard checks only the Restic password for the placeholder; SMB credentials that still hold it fail at mount time.
- Moving a backup source fails the job until `paths` is updated.
- Removing the UTC suffix from a timer brings back early firing during switches.

## Where

- `modules/nixos/backup/default.nix` (`stateDir`, `mountReset`, `repositoryCheck`, `guard`, `resticJob`, `retryCommand`, `timer`, `fileSystems` automount options)
- `modules/nixos/backup/retry.sh`
- `modules/nixos/backup/capture.sh`
- `modules/nixos/backup/stale.sh`
