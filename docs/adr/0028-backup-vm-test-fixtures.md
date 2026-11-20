# Backup VM test fixtures force each alert and failure path

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

`tests/backup.nix` tests `modules/nixos/backup` in a VM with a local repository instead of the NAS share. Several paths need specific conditions to trigger.

## Decision

- `services.openssh.enable` is on because it writes the `authorized_keys` file the status receiver test reads.
- `alert.nasFreePercent = 100` keeps free space always below the threshold, so the first success alerts and the next does not.
- The `partial` job backs up `/sys/bus/pci/rescan`, which is write-only in sysfs, so even root's read fails and restic exits 3.
- `stale_check()` runs `systemctl reset-failed` before each start, since back-to-back starts would trip systemd's start limit.

## Consequences

If the module's alert threshold or status receiver changes, these fixtures need to change with it.

## Where

- `tests/backup.nix` (`nodes.machine`, `stale_check` in `testScript`)
