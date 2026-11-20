# Every failed unit on tleilax sends one Hark alert per hour

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

tleilax sends its status nowhere else, so failures must reach Tony directly. Hark is reachable as `svc:hark` on the tailnet. A systemd drop-in cannot clear `OnFailure=`, since it is a dependency. Some units retry and alert on their own terms.

## Decision

- A `service.d` drop-in adds `OnFailure=fleet-alert@%n.service` to every service.
- `fleet-alert` skips units listed in `dotfiles.alerts.exclude` (those that alert after their retries) and its own instances, so a failed alert does not alert in turn.
- The alert goes to the "Fleet" project through a Hark service integration webhook that only tleilax can decrypt. It names the unit and its result, never log lines.
- The Idempotency-Key includes the UTC hour, so a unit alerts at most once per hour however often it fails.
- Alerts stay off while `dotfiles.alerts.webhookFile` is null; the encrypted webhook file now exists.

## Consequences

A unit with its own alerting must be added to `dotfiles.alerts.exclude`, as the Restic units are.

## Where

- `machines/tleilax/alerts.nix` (`sendAlert`, `fleet-alert@`, `fleet-alert-dropins`)
- `machines/tleilax/backup.nix` (`dotfiles.alerts.exclude`)
