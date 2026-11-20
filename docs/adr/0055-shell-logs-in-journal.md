# Stillsuit shell logs go to the bounded user journal

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The shell writes informational logs that are useful across restarts. A per-service log file would grow without a bound unless it had its own rotation.

## Decision

`stillsuit-shell.service` sends stdout and stderr to the journal with `SyslogIdentifier = "stillsuit-shell"`. `configuration.nix` bounds the shared journal at 14 days (`MaxRetentionSec`), 1 GiB persistent (`SystemMaxUse`) and 256 MiB runtime (`RuntimeMaxUse`). There is no separate per-service copy.

## Consequences

Shell logs older than 14 days, or pushed out by other units under the 1 GiB cap, are lost. Read them with `journalctl --user -u stillsuit-shell --since '14 days ago'`. Changing the journald limits in `configuration.nix` changes Stillsuit's log retention.

## Where

- `modules/home/stillsuit/service.nix` (`StandardOutput`, `StandardError`, `SyslogIdentifier`)
- `configuration.nix` (`services.journald.settings.Journal`)
