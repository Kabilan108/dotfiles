---
name: niri-computer-use
description: Desktop inspection and control for NixOS Wayland sessions running the niri compositor. Use when Codex needs to take screenshots, inspect niri windows/workspaces/outputs, focus or navigate windows with `niri msg`, move the pointer, click left/right/middle, type text, send key chords, or prototype agentic computer-use workflows on this desktop.
---

# Niri Computer Use

Use this skill for agentic desktop interaction on the local niri Wayland session. Prefer compositor-native state and navigation through `niri msg`; use synthetic input only when an application surface actually needs pointer or keyboard events.

## Quick Start

From the skill directory:

```bash
scripts/acu-state --summary
scripts/acu-screenshot /tmp/desktop.png
scripts/acu-niri focus-window --id 5
scripts/acu-input move 0.5 0.5 --absolute
scripts/acu-input click left
scripts/acu-input type "hello"
scripts/acu-input shortcut mod+a
```

The scripts run tools already on `PATH` first. When a helper is missing, they fall back to `nix-shell -p <package> --run ...` if `nix-shell` is available.

## Workflow

1. Inspect state before acting:
   - Run `scripts/acu-state --summary` for a compact list of outputs, workspaces, windows, focused window, layers, keyboard layout, and niri version.
   - Run `scripts/acu-state --json` when exact ids, geometry, app ids, or workspace ids are needed.
2. Prefer `niri msg` for navigation:
   - Focus by id with `scripts/acu-niri focus-window --id <id>`.
   - Focus by title/app substring with `scripts/acu-niri focus-window --title <text>` or `--app <app-id>`.
   - Use `scripts/acu-niri action <niri-action> [args...]` for safe compositor actions such as `focus-column-left`, `focus-column-right`, `focus-workspace`, `open-overview`, and `close-overview`.
3. Take screenshots for visual grounding:
   - Use `scripts/acu-screenshot /tmp/desktop.png` for the full desktop.
   - Use `scripts/acu-screenshot --screen /tmp/screen.png` for the focused output.
   - Use `scripts/acu-screenshot --geometry "x,y widthxheight" /tmp/crop.png` for crops.
4. Use input events last:
   - Use `scripts/acu-input type "text"` for text entry.
   - Use `scripts/acu-input key ctrl+l` for key chords.
   - Use `scripts/acu-input shortcut mod+a` for niri desktop shortcuts. The script maps niri's `Mod` spelling to `dotool`'s `super` modifier.
   - Use `scripts/acu-input move X Y --absolute` where `X` and `Y` are fractions from `0.0` to `1.0`.
   - Use `scripts/acu-input click left` or `scripts/acu-input click right` only after focusing or moving to a known target.

## Tool Notes

- `niri msg` is the primary API. It exposes outputs, workspaces, windows, layers, focused window, keyboard layouts, event streams, and many navigation/layout actions.
- `grim` works for screenshots on this desktop and can be fetched with `nix-shell -p grim`.
- `wtype` is installed and works for Wayland text/key injection when the focused surface accepts virtual keyboard input.
- `dotool` can be fetched with `nix-shell -p dotool` and works for pointer movement and clicks through uinput.
- `dotool` desktop key chords use modifiers named `super`, `ctrl`, `alt`, `altgr`, and `shift`. Use `super+a` directly or `scripts/acu-input shortcut mod+a` when translating from niri config bindings.
- `ydotool` needs `ydotoold`; without the daemon it fails with a missing socket. Do not choose it as the default path unless the daemon is running.
- `wlrctl pointer` segfaulted during local probing; avoid building workflows around it here.

## References

Read `references/survey.md` for the local tool survey and known-good probes from this desktop.
