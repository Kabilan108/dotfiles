---
name: fleet
description: Use when a task involves another machine in the fleet (jacurutu, sietch, tleilax) - running commands remotely, checking a service on another box, configuring a fleet machine, or deciding where a workload should run.
---

## Fleet

Read `~/.config/fleet/computers.md` first — it is generated from `lib/fleet.nix`
in ~/dotfiles and describes every machine: role, tailnet address, repo roots,
and which machines it may SSH into.

## Rules

- Access is directional. Only use `ssh <host>` toward machines listed under
  "can ssh into" for the machine you are on. Never SSH toward jacurutu.
- One-off commands: `ssh <host> '<command>'` — non-interactive, no tmux.
- Interactive/long-running work on a remote box: run it inside that host's
  tmux (`ssh <host> tmux new-session -d -s <name> '<command>'`), then report
  the session name so the user can attach. Plain interactive `ssh <host>`
  auto-attaches the `main` tmux session.
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
