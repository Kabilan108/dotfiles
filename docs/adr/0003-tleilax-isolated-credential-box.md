---
paths:
  - machines/tleilax
  - lib/fleet.nix
  - docs/tailscale-policy.jsonc
---

# Credential services run on tleilax, which sietch and agents cannot reach

sietch runs coding agents as Tony's user, so anything sietch can log in to, decrypt or build for is within an agent's reach. Executor v2 and atlas, which hold third-party credentials, therefore run on a separate Raspberry Pi instead of beside the agents on sietch, where Executor v1 ran. Only jacurutu reaches tleilax: Tony's YubiKeys log in, and the laptop's agent key can only start a signed deploy or list sessions through deploy-gate.

## Consequences

- sietch has no SSH key tleilax accepts, no tailnet grant to it except `svc:executor-v2`, no secret recipient on its files, and no binary cache or build that tleilax trusts. A change that adds any of these reverses the decision.
- tleilax builds its own aarch64 closures, so deploys are slow.
- No coding agent work runs on tleilax, and agents cannot unlock it after a reboot.
