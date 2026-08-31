---
name: niri-computer-use
description: Desktop inspection and control for the local NixOS + niri Wayland session. Use when an agent needs to inspect windows or workspaces, capture hidden windows, focus or launch apps, click, type, scroll, use AT-SPI, or recover desktop focus. Route browser work to agent-browser/CDP and terminal work to tmux; use acu when the compositor or pixels must solve the task.
---

# Niri computer use

Use `acu`, available on PATH, for compositor state and actions plus Wayland-native input. Its source is in `scripts/acu`. Treat it as a verification camera around app IPC and compositor control. Synthetic input is the last choice, and each action needs an observable check.

## Route before using pixels

| Task | Channel |
|---|---|
| Web page or web app | `agent-browser` against Helium's agent CDP instance. Read the `helium-browser-use` skill for tab discipline |
| Terminal or development work | `tmux send-keys` and `capture-pane`; do not click or type into terminal pixels |
| Media playback | `playerctl` |
| Quickshell panels | `qs ipc -c stillsuit call <target> <fn>` or `stillctl` |
| Clipboard | `wl-copy` and `wl-paste` |
| Window and workspace management | `acu state`, `acu focus`, `acu spawn`, or `niri msg action ...` |
| Apps with a useful AT-SPI tree | `acu ui` and `acu act`; these work without focus, including on hidden workspaces |
| Other GUI work | The `acu` pixel loop below; input requires focus |

Chromium and Electron expose useful AT-SPI trees only when launched with `--force-renderer-accessibility`. Slack and Discord wrappers include it. Ask before relaunching a user's app to add accessibility or CDP flags.

## Start and run the loop

```bash
acu doctor
acu state
```

1. Capture current pixels with `acu shot --window <id>` or `acu shot`. Add `--grid` for a 100-pixel coordinate overlay and view the image before choosing coordinates.
2. Prefer `acu key` or `acu type` to pointer input. For a pointer action, use coordinates from the current image with `acu click --window <id> --local X,Y`.
3. Capture again or inspect `acu state`. Check an outcome that would be false if the action missed.

## Command reference

```bash
acu doctor
acu state [--json]
acu shot [--window ID | --app STR] [--grid] [-o PATH]
acu shot [--out-name eDP-1]
acu wait --app STR|--title RE [--timeout 10]
acu wait --gone ID
acu focus ID|--app STR|--title RE
acu focus --back
acu spawn -- CMD...                     # launch normally; the app may take focus
acu spawn --wait -- CMD...              # wait for a new window and print its data
acu click [left|right|middle] --window ID --local X,Y [--double]
acu click --at X,Y
acu point X Y | acu scroll DY [DX]
acu type "text" | acu key ctrl+l mod+Return
acu ui --window ID [--find STR]
acu act --window ID <element-id> [--set-text S]
acu restore
```

`acu key` sends `mod+...` chords through uinput because niri ignores compositor bindings from virtual keyboards. Plain chords go to the focused window. `acu ui` element IDs belong to one tree snapshot, so inspect the tree again after the UI changes. Chromium's address bar rejects `--set-text`; web form fields and GTK entries accept it.

`--app` and `--title` must match exactly one window. Use the window ID when a match is ambiguous.

## Coordinates and focus

- Window-local coordinates come from `acu shot --window` and go to `--local`. For a tiled window, `acu click --window` briefly floats it to obtain an origin, clicks, then tiles it again. Capture fresh coordinates if it reports a size change.
- Full-desktop shots use global logical coordinates. Add the output offset shown by `acu state` when an output does not start at `(0,0)`.
- Focus follows the pointer. Reassert the target with `acu focus` before typing after pointer movement.
- Keyboard and text input always go to the focused window. Seat input cannot act on a hidden window.
- `acu spawn` is a normal visible launch and may take focus. Use CDP, AT-SPI, or tmux for work that must not disturb the visible desktop.
- Record what you displace and finish with `acu restore`. Stop if the user begins moving the pointer during the task.

## Known traps

| Symptom | Cause | Recovery |
|---|---|---|
| Focus actions do nothing and `focused-window` is null | Overview is open | `niri msg action close-overview`; `acu` also closes it before focus actions |
| A click misses or opens overview | Coordinates came from stale or guessed pixels | Capture again and use `--grid` or window-local coordinates |
| Text reaches the wrong window | Pointer motion changed focus | Run `acu focus <target>` immediately before typing |
| A raw niri screenshot replaces clipboard data | `niri msg action screenshot-*` copies the image | Use `acu shot`, which restores the clipboard |
| `wlrctl` or `wev` is absent from PATH | The Home Manager generation lacks it | `acu` resolves it with nix-shell and caches the path; the first call is slow |

## State schema

`acu state --json` returns `overview_open`, `focused_window_id`, `outputs`, `workspaces`, and `windows`. Niri window IDs are compositor IDs, not PIDs. `floating_pos` is global logical and exists only for floating windows.

## App notes

Before driving an app, check `references/apps/<app-id>.md`. Add a dated note only after proving a non-obvious workflow, quirk, or dead end that would change the next agent's approach.

## References

- `references/environment.md` covers verified protocols, tool paths, config locations, CDP endpoints, and probe evidence.
- `references/recipes.md` has focused examples for chat apps, dialogs, recovery, and AT-SPI.
- `references/apps/` stores per-application field notes.
