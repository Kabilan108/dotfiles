---
name: fleet
description: Use when a task involves another machine in the fleet (jacurutu, sietch, tleilax), such as running commands remotely, checking a service on another box, rebuilding or deploying a machine, or deciding where a workload should run.
---

## Fleet

Fleet configuration lives in `~/dotfiles`, a NixOS flake whose main branch is
`nixos`. sietch and jacurutu build from the root `flake.nix`; tleilax builds
from the separate flake in `~/dotfiles/raspi/`, which has its own lock.

Read `~/.config/fleet/computers.md` first. It is generated from
`lib/fleet.nix` and lists every machine's role, tailnet address, repo roots,
and which machines it may SSH into. Scripts read the same data from
`~/.config/fleet/fleet.json` (`self`, `machines`, `devices`); use it instead
of hardcoding host names or IPs.

For work involving `dar-es-balat`, NAS services, or the boundary between LAN
and tailnet access, also read `~/dotfiles/docs/nas-network-policy.md` before
inspecting or changing policy.

## Access

- Access is directional. Only SSH toward machines listed under "can ssh
  into" for the machine you are on. Never SSH toward jacurutu.
- **Agents always use the `<host>-agent` aliases** (e.g. `ssh sietch-agent
  '<command>'`). They authenticate with this machine's restricted agent key
  in BatchMode: no YubiKey touch, no prompts, no hangs. Plain `ssh <host>` is
  the human path (hardware key, lands in the host's `main` tmux session); keep
  it out of scripts.
- One-off commands (`ssh <host>-agent '<cmd>'`) bypass tmux. For interactive
  or long-running work, run it inside that host's tmux
  (`ssh <host>-agent 'tmux new-session -d -s <name> "<command>"'`) and report
  the session name so the user can attach.
- From a remote tmux view, `M-s` returns to the local machine's session
  picker, and a plain detach (prefix+d) returns to the session you came from.

## Changing and rebuilding machines

- Fleet machines are NixOS. Configuration changes go through `~/dotfiles`,
  never ad-hoc edits to system files. The registry (`lib/fleet.nix`) drives SSH
  config, authorized keys, host colors and `computers.md`; change it there and
  rebuild.
- When a change needs a rebuild, the default is to tell Tony with
  `notify-send` and leave the rebuild to him.
- On jacurutu, with Tony's explicit approval, you may rebuild sietch or
  tleilax over SSH:
  - sietch needs his sudo password, so start the rebuild in a tmux pane he
    can take over to enter it.
  - tleilax builds its own closure and switches with passwordless sudo:
    `nixos-rebuild switch --flake ~/dotfiles/raspi#tleilax --build-host tleilax-agent --target-host tleilax-agent --sudo`
- Make a fleet-wide change once, in one checkout. A branch or a separate
  worktree is fine, and is often what Tony asks for.
- On any branch other than `nixos`, commit and push freely, so Tony can review
  and merge on GitHub instead of hunting for worktree paths.
- On `nixos`, commit but leave pushing to Tony: he reviews those commits
  locally first.
- Each other machine runs `git pull` in `~/dotfiles` before it rebuilds. Never
  copy or patch uncommitted edits into another machine's checkout.

## Placement

- sietch takes heavy or parallel agent work and anything needing `/vault`
  data; jacurutu takes interactive and desktop tasks only; tleilax is a
  low-power Pi for status and appliance jobs.
- Long jobs on sietch end with an artifact the user can find: a pagebin URL,
  a file path, or a Hark notification (see the notify skill).

## SSH from agent harness shells

Plain `ssh <host>-agent` works from agent sandboxes. If `Bad owner or permissions on ~/.ssh/config` comes up, look for regressions in `modules/home/fleet.nix` in `~/dotfiles` rather than reaching for `-F none` workarounds.
