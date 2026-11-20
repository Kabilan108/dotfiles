# The media library mounts over SMB with 1 MiB seal buffers, and Jellyfin waits for it

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

- With `seal`, the CIFS client encrypts each request in a buffer sized from `rsize`/`wsize`. At the 4 MiB default that is an order-4 allocation, which failed under memory fragmentation mid-copy (ENOMEM on close).
- The NAS share ACL decides who may write. Mount options only set how files look on sietch.
- Jellyfin's library paths inside the old container were `/media/...`. Keeping them valid preserves watch state and metadata without touching the database.
- As a plain local bind, `/media` joined `local-fs.target`, which then waited on `/library` and the network. systemd broke that cycle at boot by mounting `/library` before the network.

## Decision

- Both library mounts use SMB 3.1.1 with `seal`, `rsize` and `wsize` of 1 MiB, `uid=kabilan`, `gid=users`, `nodev`, `nosuid`, `noexec` and `_netdev`.
- `/library-rw` (`svc-library-rw`) is an automount with `nofail`, so a missing NAS or placeholder credentials fail the access instead of the boot.
- `/library` (`svc-library-ro`) is read-only, mounted at boot and `hard` with a 60 s mount timeout. While the NAS is away, reads wait instead of failing, and a library scan can't see files vanish.
- `/media` binds `/library` with `_netdev`, which puts it under `remote-fs.target`. Jellyfin has `RequiresMountsFor=/media`, so an unmounted NAS stops Jellyfin instead of showing it an empty library.

## Consequences

- Processes reading `/library` block while the NAS is unreachable.
- The backup module's CIFS mount shares `vers=3.1.1`, `seal` and the hardening flags but not the 1 MiB `rsize`/`wsize` cap.

## Where

- `modules/nixos/selfhost/library.nix` (`common`, `onDemand`, `fileSystems."/library"`, `fileSystems."/library-rw"`)
- `modules/nixos/selfhost/jellyfin.nix` (`fileSystems."/media"`, `systemd.services.jellyfin.unitConfig`)
