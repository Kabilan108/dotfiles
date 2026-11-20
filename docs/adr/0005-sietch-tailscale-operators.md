# Agents on sietch need sudo to change the main Tailscale client

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Agents run as kabilan on sietch. The shared configuration sets `--operator=kabilan` on Tailscale. sietch also runs a separate Moberg Tailscale client.

## Decision

- sietch forces `services.tailscale.extraSetFlags` to `--operator=`, which clears the shared default, so changing Tailscale (Serve backends included) needs sudo.
- The Moberg Tailscale client keeps kabilan as operator, so agents can change that client without sudo.

## Consequences

Revisit the Moberg client's operator if the office moves to Headscale.

## Where

- `machines/sietch/default.nix` (`services.tailscale.extraSetFlags`, `dotfiles.mobergTailscale`)
- `configuration.nix` (`services.tailscale.extraSetFlags`)
