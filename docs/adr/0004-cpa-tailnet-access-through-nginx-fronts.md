---
paths:
  - modules/nixos/selfhost/cliproxyapi.nix
  - modules/home/cpa-clients.nix
---

# CPA reaches the tailnet only through two path-allowlisting nginx fronts

CPA serves inference and management on one listener, and Tailscale Serve proxies from loopback, so CPA sees every tailnet request as local and `allow-remote: false` cannot refuse it. Publishing CPA's port directly lost for that reason. Two loopback nginx vhosts are published instead, as separate Tailscale Services: `cliproxyapi` (8320) forwards only the inference prefixes and `cpa-admin` (8321) only the management paths; everything else gets nginx's 404, and local callers on sietch use CPA's port directly.

## Consequences

- The tailnet policy decides who reaches inference and who reaches management, per service. The inference key `claudex-tailnet` is shared, sits in the repo and is not a secret.
- A new CPA route reaches the tailnet only after it is added to one front's prefix list; `tests/cpa/run.sh` checks both lists, including refused management and traversal paths.
