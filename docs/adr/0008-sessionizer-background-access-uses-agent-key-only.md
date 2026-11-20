---
paths:
  - packages/sessionizer/fleet.go
  - modules/nixos/deploy/gate.sh
  - bin/sessionizer
---

# Reach other hosts in the background only with the agent key and open login connections

Login keys need a security key touch, so the picker cannot use them unattended. It lists other hosts with the per-host `agent-<host>` key, which on gated hosts can run only the exact command `"$HOME/bin/sessionizer" --inventory`, and it switches sessions only over an already open login connection with public key authentication off, failing instead of prompting. Using login keys for background listing lost because every refresh would ask for a touch; a machine without an agent key reaches no other host.

## Consequences

The inventory command's spelling is an interface with `deploy-gate`, and gated hosts must keep sessionizer in `environment.systemPackages`. Proxy commands work only while a login connection is open.
