# tleilax is a credential box that agents and sietch cannot reach

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

tleilax is a Raspberry Pi 4 that runs credential services: Executor v2 and atlas. No coding agents run there. sietch runs coding agents, so it must have no way in. Only jacurutu reaches tleilax: Tony's YubiKeys log in, and the laptop's agent key can only start a signed deploy or list sessions through `deploy-gate` (`modules/nixos/deploy/gate.sh`). Install and recovery are in `docs/tleilax-install.md`.

## Decision

- tleilax builds from `nixpkgs.lib.nixosSystem` without the desktop modules or shared overlays. atlas is therefore built from `${inputs.atlas}/nix/package.nix` with the Pi's own package set.
- Only root's Nix is used. kabilan is not a trusted user, and the only binary cache is cache.nixos.org; nothing sietch signs or serves is trusted.
- Accounts have no passwords; SSH keys come from `lib/fleet.nix` through `modules/nixos/fleet.nix`. OpenSSH listens only on `tailscale0`. `/etc/ssh/ssh_host_ed25519_key` is the agenix identity and never leaves the encrypted root; its public half was generated at install.
- Services listen on loopback. A tailnet-reachable one also sets `selfhost.tailnetServices.<name>.port`, and `tag:credentials` is the only tag the policy lets advertise it. Their secrets are encrypted to this host and the YubiKey age recipients only.
- atlas has no tailnet service: only Executor on this box calls it, so the Jira and Bitbucket tokens never leave the Pi. It is stateless: each request carries its credentials in `X-Atlas-*` headers, and `mcp serve` skips the update check and the disk cache.
- Networking is Ethernet with DHCP and a router reservation (`initrdUnlock.lanAddress`). IPv6 is off so the egress filter has no LAN IPv6 prefix to chase. The `egress` nftables table allows loopback, the tailnet, established replies, the router at 10.0.0.1 (the Xfinity default gateway) for DNS and DHCP, and the Moberg office subnet through its VPN, and drops other private ranges.
- Tailscale reads `/var/lib/tailscale/first-boot-auth-key` only while logged out: a single-use key for `tag:credentials` placed during the install.
- Agent logins to gated hosts may only run `deploy-gate`. Gated hosts need sessionizer in their system packages, and tleilax installs it at `~/bin/sessionizer`, where the laptop's picker attaches. Its sessionizer config offers only `~` with `max_depth = 0` (the search path itself): deploy-gate gives the agent key the inventory alone, which carries the picker's previews, and opening a session uses Tony's login connection.

## Consequences

If the home LAN subnet changes, update the gateway in `network.nix`. Adding a tailnet service on tleilax needs the policy to allow `tag:credentials` to advertise it. Any new host added to `gatedAgentLogins` needs sessionizer installed. Executor v1 has since been retired from sietch rather than kept alongside v2.

## Where

- `flake.nix` (`nixosConfigurations.tleilax`)
- `machines/tleilax/default.nix` (`nix.settings`, `services.openssh`, home-manager sessionizer config)
- `machines/tleilax/services.nix`
- `machines/tleilax/atlas.nix`
- `machines/tleilax/network.nix` (`gateway`, `services.tailscale.authKeyFile`, `networking.nftables.tables.egress`)
- `lib/fleet.nix` (`hosts.sietch.canAccess`, `hosts.tleilax.hostPubkey`, `agentGateRestrictions`, `deploy.gatedAgentLogins`)
