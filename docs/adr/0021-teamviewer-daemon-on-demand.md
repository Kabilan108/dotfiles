# TeamViewer's root daemon does not start at boot

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

`teamviewerd` runs as root and is only needed while TeamViewer is in use. The NixOS module wants it at boot.

## Decision

`systemd.services.teamviewerd.wantedBy` is forced empty on every host with `services.teamviewer.enable`.

## Consequences

The daemon has to be started before using TeamViewer, and it isn't listening the rest of the time.

## Where

- `modules/nixos/teamviewer.nix` (`systemd.services.teamviewerd.wantedBy`)
