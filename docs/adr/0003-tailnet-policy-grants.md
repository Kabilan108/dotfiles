# Tailnet grants follow each device's trust level

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The Tailscale admin console holds the live policy; `docs/tailscale-policy.jsonc` is the repository copy. sietch runs coding agents and is tagged `tag:server`, so it drops out of `autogroup:member` and `autogroup:self`. tleilax holds credential services (Executor v2 and atlas) under `tag:credentials`. The phone never uses SSH. Grokbot joins through a Tailscale OAuth app. Wireless ADB on the Pixel uses randomized pairing and connection ports.

## Decision

- jacurutu is the control plane and reaches every destination on every port.
- sietch gets nothing on tleilax. Away from home, jacurutu reaches tleilax's boot-time unlock through sietch over the LAN, which this policy does not govern.
- sietch may open any TCP port on the Pixel, for wireless ADB, and nothing else there.
- `tag:server` has its own short service grant (`svc:cliproxyapi`, `svc:siren`, `svc:executor-v2`, `svc:hark`), because its consumers use the svc names too (dictator calls siren). Services join that list only when something on sietch needs them.
- `autogroup:member` reaches the hosted services except `svc:cliproxyapi`: only jacurutu, sietch and agent boxes send inference.
- The phone reaches Blocky's DoH endpoint (`svc:blocky`), the CPA dashboard (`svc:cpa-admin`), and every TCP port except 22 on sietch and jacurutu, for T3 Code and dev servers. It reaches tleilax's services only through svc grants.
- The iPad reaches TCP 22 and 443 on the three hosts: SSH, and T3 Code over Tailscale Serve.
- `tag:credentials` reaches `svc:hark` on 443 for failed-unit alerts and `tag:nas` on 445 for SMB backups, and nothing else. Atlas runs on tleilax's loopback for Executor v2 and needs no grant.
- `tag:grokbot` exists so Grokbot leaves `autogroup:member` and gets only its own grant: `svc:executor-v2` and sietch on 443, where Tailscale Serve on the machine's HTTPS address carries the T3 MCP.
- `tag:nas` is for dedicated storage appliances with no outbound fleet access.

## Consequences

Edit the console first, then copy the change into the jsonc file. The `tests` block encodes these boundaries; a grant that breaks one fails the save. A new selfhosted service that sietch itself consumes needs an entry in the `tag:server` grant as well as the member grant.

## Where

- `docs/tailscale-policy.jsonc` (`tagOwners`, `grants`, `tests`)
