# Link a hand-written niri config and install agent computer-use tools

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

niri-flake generates `~/.config/niri/config.kdl` from `programs.niri.config` unless told not to. Tony keeps a hand-written `config.kdl` in the repo, linked out of the store so edits apply without a rebuild, so the generated file would collide with that symlink.

The niri-computer-use skill's `acu` CLI drives the desktop and needs Wayland tools on PATH: wlrctl as the virtual pointer, wev as the input-event oracle, dotool for uinput key events that reach niri compositor binds, and grim for output screenshots.

## Decision

The niri home module sets `programs.niri.config = null` and links `config.kdl` with `mkOutOfStoreSymlink`. It installs wlrctl, wev, dotool and grim in `home.packages` for `acu`.

## Consequences

Removing `programs.niri.config = null` breaks activation with a file collision. If `acu` stops using one of the four tools, its package can go.

## Where

- `home/desktop/wayland/compositors/niri/default.nix` (`programs.niri.config`, `home.packages`)
- `agents/skills/niri-computer-use/`
