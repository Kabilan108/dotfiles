# The deploy receiver runs root Nix and git on store files and root-owned paths only

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The receiver runs as root and builds a commit fetched over HTTPS into a root-owned bare clone. The system `nix.conf` has include lines for files outside the store, such as the access-token include. The switch lock `/run/fleet-switch.lock` is shared with `bin/rebuild` and `deploy-switch`; anyone who can open it can hold it. In Nix 2.34, `--no-write-lock-file` turns the refusal from `--no-update-lock-file` back into a warning.

## Decision

- The receiver's Nix reads only `receiverNixConf`: the system `nix.conf` with its include lines removed. The derivation fails if the word "include" survives. Its directory has no registry, machines or netrc file. `NIX_USER_CONF_FILES` and `NIX_CONFIG` are empty and `NIX_REMOTE=local`.
- `HOME` and the XDG directories point into `/var/lib/deploy-receiver` and `/var/cache/deploy-receiver`. `GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_NOSYSTEM=1`.
- tmpfiles creates the lock file 0600 root, and the receiver opens it under `umask 077`, so no other user can open it to hold the lock.
- The receiver builds outside the lock with `--no-update-lock-file` and without `--no-write-lock-file`. The `result` link in the state directory keeps the system from garbage collection until the switch. It then takes the lock, checks again that the tag moves forward from the running commit, and switches with `--store-path`.

## Consequences

- Nothing a user can write reaches a root Nix or git process in the receiver.
- On a Nix upgrade, check whether `--no-write-lock-file` still weakens `--no-update-lock-file` before adding it.
- A manual rebuild that finishes during the build is respected, because the forward check runs again under the lock.

## Where

- `modules/nixos/deploy/default.nix` (`receiverNixConf`, `systemd.services.deploy-receiver.environment`, `systemd.tmpfiles.rules` for `switchLock`)
- `modules/nixos/deploy/receiver.sh` (build and lock section)
