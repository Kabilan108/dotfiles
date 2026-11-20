---
paths:
  - modules/nixos/deploy/default.nix
  - modules/nixos/deploy/broker.sh
  - modules/nixos/deploy/trigger.sh
  - modules/nixos/deploy/run-record.sh
---

# Unprivileged callers start a deploy through a root broker socket, not a polkit rule

A receiver's own user, and agent keys through `deploy-gate`, must be able to start `deploy-receiver.service` and nothing else. A polkit rule allowing "start" on that unit lost because systemd does not pass the job mode to polkit: the same rule would allow `--job-mode=flush`, which cancels every other queued job on the host. Members of the `deploy-trigger` group connect to `/run/deploy-trigger.sock` instead, and each connection runs a root broker that reads nothing from the caller, calls `StartUnit` with the fixed job mode `replace`, replies with the job ID and exits.

## Consequences

- The broker cannot report how the run ended, and systemd forgets a finished oneshot's result, so `deploy-receiver-run` records each run by job ID in `/run/deploy-receiver/runs` and `deploy-trigger` follows that record.
- The receiver never depends on its caller: a caller that disconnects or never reads does not stop the deploy or hold a connection slot.
- Anything the broker starts to read from the caller reopens the boundary. Moving to polkit needs systemd to expose the job mode to polkit rules first.
