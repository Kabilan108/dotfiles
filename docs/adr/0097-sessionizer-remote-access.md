# Sessionizer reaches other hosts only through the agent key, open login connections and a fixed remote path

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The picker runs on the laptop and lists sessions and directories on other fleet hosts. Every host installs sessionizer from `packages/sessionizer` through home-manager, and other hosts answer the picker's `sessionizer --inventory` and proxy commands through `"$HOME/bin/sessionizer"` (also used from `docs/tleilax-install.md`).

Login keys need a security key touch, so the picker cannot use them in the background. Each host has an `agent-<host>` key instead. On gated hosts (`deploy.gatedAgentLogins` in `lib/fleet.nix`), that key's forced command is `deploy-gate`, which allows exactly the string `"$HOME/bin/sessionizer" --inventory` and runs `/run/current-system/sw/bin/sessionizer --inventory` with a bare PATH (`inheritPath = false`).

## Decision

- `bin/sessionizer` execs the first executable of `/etc/profiles/per-user/$USER/bin/sessionizer` and `~/.nix-profile/bin/sessionizer`, so remote callers keep a fixed path whichever Home Manager profile layout a host uses.
- `remoteHosts` returns no hosts when `~/.ssh/agent-<localhost>` is missing, so a machine without an agent key reaches no other host.
- `remoteSessionizer` always sends `"$HOME/bin/sessionizer"` spelled exactly that way. `SESSIONIZER_REMOTE_PROGRAM` swaps in another build on the remote side for tests; gated hosts then refuse the inventory.
- `masterSSH` runs commands over an already open login connection with `ControlMaster=no`, `BatchMode=yes` and `PubkeyAuthentication=no`, so it fails instead of asking for a touch.
- The package wraps the binary with `--suffix PATH` for tmux, openssh and git, not `--prefix`. The picker must talk to the tmux server with the user's own tmux, while under `deploy-gate` the bare PATH still gets git for directory status.

## Consequences

- Changing the inventory command's spelling or arguments breaks listing on gated hosts until `modules/nixos/deploy/gate.sh` changes with it.
- Gated hosts must keep sessionizer in `environment.systemPackages`; `modules/nixos/deploy/default.nix` asserts this.
- Proxy commands (`--proxy-switch`, `--proxy-current`) only work while a login connection is open; without one they fail rather than prompt.

## Where

- `bin/sessionizer`
- `packages/sessionizer/default.nix` (`postInstall` wrapper PATH)
- `packages/sessionizer/fleet.go` (`remoteHosts`, `remoteSessionizer`, `masterSSH`)
- `modules/nixos/deploy/gate.sh` (`inventory_command`)
