---
name: fleet
description: Use when a task involves another machine in the fleet (jacurutu, sietch, tleilax) - running commands remotely, checking a service on another box, configuring a fleet machine, or deciding where a workload should run.
---

## Fleet

Read `~/.config/fleet/computers.md` first — it is generated from `lib/fleet.nix`
in ~/dotfiles and describes every machine: role, tailnet address, repo roots,
and which machines it may SSH into.

## Rules

- Access is directional. Only SSH toward machines listed under "can ssh
  into" for the machine you are on. Never SSH toward jacurutu.
- **Agents always use the `<host>-agent` aliases** (e.g. `ssh sietch-agent
  '<command>'`): they authenticate with this machine's restricted agent key
  in BatchMode — no YubiKey touch, no prompts, no hangs. Plain `ssh <host>`
  is the human path (hardware key + tmux auto-attach); do not use it from
  scripts.
- Interactive/long-running work on a remote box: run it inside that host's
  tmux (`ssh <host>-agent 'tmux new-session -d -s <name> "<command>"'`),
  then report the session name so the user can attach.
- Fleet machines are NixOS. Configuration changes go through `~/dotfiles`
  (edit + `nh os switch` or `sudo nixos-rebuild switch --flake ~/dotfiles#<host>`),
  never ad-hoc edits to system files. The registry itself (`lib/fleet.nix`)
  drives SSH config, authorized keys, host colors, and this doc — change it
  there and rebuild.
- Long jobs on sietch should end with a clear artifact the user can find
  (a pagebin URL, a file path, or a `discord-notify` message when available).
- Workload placement: sietch for heavy/parallel agent work and anything
  needing /vault data; jacurutu only for interactive/desktop tasks; tleilax
  is low-power (Pi) — status/appliance jobs only.

## SSH from agent harness shells

Plain `ssh <host>-agent` works from agent sandboxes. If `Bad owner or permissions on ~/.ssh/config` ever comes up, look for regressions in `modules/home/fleet.nix` rather than reaching for `-F none` workarounds.
