# Blocky publishes only DoH and plain tailnet DNS, and keeps no record of queries

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

- Blocky's normal HTTP listener exposes unauthenticated management (OpenAPI) and profiling (debug) routes, even on loopback.
- Blocky serves the tailnet. The host's own resolver may use Blocky, so Blocky can't depend on DNS to find its upstreams or blocklists.
- The native NixOS module orders Blocky before `nss-lookup.target`, as an early-boot resolver.
- Blocky's privacy redaction preserves name lengths and isn't applied to every error.
- Tailscale Serve handles decrypted DoH messages before the localhost proxy.

## Decision

- The Blocky package is patched to drop `api.RegisterOpenAPIEndpoints` and `configureDebugHandler` from `server/server_endpoints.go`, keeping DoH.
- Blocky's HTTP listener is `127.0.0.1:8318`. The Tailscale Service `blocky` points at an nginx front on 8319 that forwards only `= /dns-query`.
- Plain DNS listens on the node's Tailscale IP, port 53, opened only on `tailscale0`.
- Upstreams and `bootstrapDns` are DoH by IP literal (1.1.1.1, 1.0.0.1).
- The unit's `before` list is cleared, and it wants and follows `network-online.target` and `tailscaled.service`.
- Blocky's stdout and stderr go to null, the query log is off, and Blocky, nginx and tailscaled run with `LimitCORE=0` and `MemorySwapMax=0`.

## Consequences

- `--replace-fail` breaks the build if upstream changes those two lines, which forces a review of the patch.
- Debugging Blocky needs its output turned back on temporarily.
- The nginx and tailscaled limits apply to everything those services handle on the host.

## Where

- `modules/nixos/selfhost/blocky.nix` (`services.blocky.package`, `settings.ports`, `upstreams`, `bootstrapDns`, `virtualHosts.blocky-doh`, `systemd.services.blocky`, `systemd.services.tailscaled.serviceConfig`)
