# ~/repos is a bind mount of /vault/repos

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Tools such as direnv key their allow lists on the real path. With `~/repos` as a symlink, `~/repos/x` and `/vault/repos/x` are two paths to them. systemd won't mount over an existing symlink.

## Decision

- `~/repos` is a bind mount of `/vault/repos`.
- The `reposMountpoint` activation script replaces an old symlink with an empty directory and creates the directory when missing. It leaves a non-empty real directory alone with a warning, for Tony to move by hand.

## Consequences

Both paths resolve to one real path. A non-empty `~/repos` directory is hidden by the mount until its contents move into `/vault/repos`.

## Where

- `modules/nixos/repos-mount.nix` (`fileSystems`, `system.activationScripts.reposMountpoint`)
