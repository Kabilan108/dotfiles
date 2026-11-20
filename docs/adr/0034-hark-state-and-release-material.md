# Hark's server state, published APKs and release secrets have separate paths and owners

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The Hark server runs as the `hark` user. Its Android release build, `scripts/android-build-release` in the hark repo, runs as kabilan and publishes APKs the server serves.

## Decision

- `dataDir` is `/vault/userdata/hark-server` and holds server state only. Android release material stays in `/vault/userdata/hark`, owned by kabilan.
- `downloadsDir` is `/vault/userdata/hark-downloads`, 0755 kabilan:users: kabilan's release script writes it and the service reads it.
- The release keystore and signing properties are agenix secrets owned by kabilan, since the release script reads them as kabilan.
- `sqlite` is in `environment.systemPackages` for manual online backups of the database: `sudo -u hark sqlite3 ... ".backup <dest>"`. Scheduled backups copy it through sietch's `services` backup job.

## Consequences

- A compromised Hark server can't read the release keystore.
- Moving the release build into the service would need these owners revisited.

## Where

- `modules/nixos/selfhost/hark.nix` (`dataDir`, `downloadsDir`, `age.secrets.hark-android-*`, `environment.systemPackages`)
