# Executor v2 runs in Podman on tleilax with its keys outside the data volume and UID-scoped egress

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Executor v2 (beta) is reachable as executor-v2.sole-pierce.ts.net. It started empty; nothing migrated from v1 on sietch. Executor refuses to start if its key source changes under an existing database. Each beta release is a new image tag. On SIGTERM the Executor host gives workerd 15 seconds to finish before killing it. workerd tries a name's next address only after a connection fails. Executor apps need MCP servers on the Moberg office network.

## Decision

- `BETTER_AUTH_SECRET` and `EXECUTOR_ENCRYPTION_KEY` come from agenix, so the data volume never holds the key that decrypts its credentials. The secret must exist before the first boot (`docs/tleilax-install.md`, "Executor v2 keys").
- Podman runs the container, so no daemon has to keep running on the Pi.
- The image is pinned by tag and digest. Bump the tag, then re-pin the digest. `EXECUTOR_NO_UPDATE_CHECK=1` skips the daily npm dist-tags check because updates arrive through these pin bumps.
- `--stop-timeout=30` outlasts workerd's 15-second grace period; Podman's default 10 would kill the container first.
- The nftables `executor` chain rejects IPv6 instead of dropping it, so workerd moves on to the next address instead of hanging until timeout. A mounted `gai.conf` prefers IPv4 for names with both address families.
- The Moberg VPN routes only the office subnet (10.1.10.0/24) through the tunnel. Pushed routes and DNS are ignored, and the office names resolve on public DNS. The profile is tleilax's own "tony2" credential, encrypted on jacurutu to this host and the YubiKeys.

## Consequences

Never regenerate the key file under an existing database. Reaching another office service means adding its origin to `tleilax.executor.officeServices`. If Executor's shutdown grace period grows, `--stop-timeout` must grow with it.

## Where

- `machines/tleilax/executor.nix` (`preferIPv4`, `virtualisation.oci-containers.containers.executor-v2`, `networking.nftables.tables.executor-v2`)
- `machines/tleilax/moberg-vpn.nix`
