---
name: fleet
description: Use when a task involves a machine in the fleet (jacurutu, sietch, tleilax)
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
  config, authorized keys, host colors, `computers.md`, and who deploys to
  whom; change it there and rebuild.
- When a change needs a rebuild, the default is to tell Tony with
  `notify-send` and leave the rebuild to him.
- Make a fleet-wide change once, in one checkout. A branch or a separate
  worktree is fine, and is often what Tony asks for.
- On any branch other than `nixos`, commit and push freely, so Tony can review
  and merge on GitHub instead of hunting for worktree paths.
- Pushing to `nixos` depends on the deploy gate below:
  - Until the deploy gate is merged and sietch and jacurutu are both rebuilt
    with it, commit on `nixos` and leave pushing to Tony.
  - After that, you may push to `nixos`. Nothing builds an unsigned commit:
    hosts deploy only tags Tony signed, and `rebuild` lists unsigned commits
    and asks first.
  - A rebuilt host has `deploy-tag` on PATH. From jacurutu, check both with
    `command -v deploy-tag && ssh sietch-agent command -v deploy-tag`. From
    sietch, ask Tony unless he has said both are rebuilt.
- Anything new that acts on a push to `nixos` (a CI build, a cache publish, an
  ACL apply) must first check for a signed tag against an allowed-signers list
  kept outside the branch, so a push can't approve itself.
- Never copy or patch uncommitted edits into another machine's checkout.

## Deploying

Tony approves a commit by signing a git tag, `deploy/<host>/<UTC time>`, with
his YubiKey. Hosts build only signed tags.

- `deploy <host>` runs on jacurutu. It fetches `origin/nixos`, lists the
  commits since the host's last signed tag, asks, signs a new tag (a YubiKey
  touch), pushes it, and starts the host's receiver over SSH. With nothing new
  it skips the signing and only starts the receiver.
- You may run `deploy` on jacurutu, but only Tony can touch the key, and the
  new keys also need their PIN typed in a terminal. Start it in a tmux pane he
  can attach to and tell him with `notify-send`. `--yes` skips the question,
  never the touch; pass it only after he approved the commit list in chat.
- The receiver (`deploy-receiver.service`) fetches GitHub into its own
  root-owned clone, checks the signature, and builds that exact commit. It
  never reads `~/dotfiles`, so an edit there deploys nothing.
- A host only moves forward: the signed commit must descend from the one it
  runs, including Tony's manual rebuilds, and its `flake.lock` must be
  complete. A deliberate rollback takes `deploy --allow-rollback <host>`,
  which asks on the terminal even with `--yes`; that's Tony's call.
- sietch takes deploys now. tleilax takes them once it builds from the root
  flake; until then `deploy` refuses it, and with Tony's explicit approval you
  rebuild it from jacurutu:
  `nixos-rebuild switch --flake ~/dotfiles/raspi#tleilax --build-host tleilax-agent --target-host tleilax-agent --sudo`
- `rebuild` is Tony's manual rebuild of the host he's on, from `~/dotfiles`.
  It lists the commits since that host's last signed tag and asks; on jacurutu,
  approving signs and pushes a tag. Leave it to him.
- sietch's `~/dotfiles` still feeds `~/bin`, the agent configs and niri's
  `config.kdl` directly, so those change on `git pull` there, with or without
  a deploy. Pull it after a deploy so the two match.

## Placement

- sietch takes heavy or parallel agent work and anything needing `/vault`
  data; jacurutu takes interactive and desktop tasks only; tleilax is a
  low-power Pi for status and appliance jobs.
- Long jobs on sietch end with an artifact the user can find: a pagebin URL,
  a file path, or a Hark notification (see the notify skill).

## SSH from agent harness shells

Plain `ssh <host>-agent` works from agent sandboxes. If `Bad owner or permissions on ~/.ssh/config` comes up, look for regressions in `modules/home/fleet.nix` in `~/dotfiles` rather than reaching for `-F none` workarounds.
