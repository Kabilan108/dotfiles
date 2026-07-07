---
name: niri-computer-use
description: Desktop inspection and control for the local NixOS + niri Wayland session. Use when an agent needs to see or drive the desktop - take screenshots of windows/outputs (including hidden workspaces), inspect windows/workspaces via niri, focus or launch apps (with or without stealing focus), click/type/scroll into GUI apps, run app tasks in the background on the agent workspace, or recover a confused desktop (overview open, focus lost). Route browser work to agent-browser/CDP and terminal work to tmux; use this skill's acu tool for everything the compositor and pixels must solve.
---

# Niri Computer Use

One tool: **`acu`** (on PATH; source lives in this skill's `scripts/`). Compositor-native state and actions via `niri msg`, Wayland-native input via wlrctl/wtype. The skill's proven identity: **a verification camera around compositor- and app-IPC control** — synthetic input is the last tier, and every action gets verified.

## Route the task before touching pixels

| Task | Channel (better than clicking) |
|---|---|
| Web page / web app | `agent-browser` against helium CDP (127.0.0.1:9222, always on) — works in background, zero focus impact |
| Terminal / dev work | `tmux send-keys` / `capture-pane` — user keeps one session per project (`tmux ls`); NEVER click/type at terminal pixels |
| Media playback | `playerctl` (Spotify etc.) |
| Quickshell panels (bar, mixer, notifs) | `qs ipc -c stillsuit call <target> <fn>` / `stillctl` |
| Clipboard | `wl-copy` / `wl-paste` (history in walker) |
| Window/workspace management | `acu state`, `acu focus`, `acu spawn`, raw `niri msg action ...` |
| GUI apps with AT-SPI trees (GTK/Qt; Chromium/Electron launched after the a11y flag) | `acu ui` (semantic element list) + `acu act` (in-process press/set-text) — **no focus, works on hidden workspaces** |
| Everything else | the `acu` pixel loop below (focus required for input) |

Electron apps (Discord, Slack, obsidian, t3code) expose AT-SPI trees only when accessibility was on at launch (the niri session now sets the screen-reader flag at startup; instances started before it need a relaunch, or `--force-renderer-accessibility`). Reading them needs nothing: `acu shot --window` sees every window, hidden or not. CDP via `--remote-debugging-port` remains the deepest channel (ask before relaunching the user's app).

## Session start

```bash
acu doctor        # env, tools, compositor, traps — fix failures before anything else
acu state         # outputs, workspaces, windows (ids, app_ids, focus, sizes)
```

## The loop: see → act → verify

1. **See.** `acu shot --window <id>` (window-local pixels, works for hidden workspaces, never moves focus) or `acu shot` (full desktop, global coords). Add `--grid` for a labeled 100px coordinate overlay. Every shot prints `path WxH` — view the image before grounding coordinates.
2. **Act.** Prefer keyboard (`acu key`, `acu type`) over pointer. Pointer: `acu click --window <id> --local X,Y` with coordinates read from the *current* shot.
3. **Verify.** Re-shot or `acu state` — assert something that would be false if the action failed. Exit code 0 is not success; pixels or compositor state are.

## Command reference

```bash
acu doctor                                   # preflight + recovery hints
acu state [--json]                           # full desktop state (schema below)
acu shot [--window ID | --app STR] [--grid] [-o PATH]   # identity-based capture
acu shot [--out-name eDP-1]                  # output capture (grim)
acu wait --app STR|--title RE [--timeout 10] # wait for window to appear
acu wait --gone ID                           # ... or disappear
acu focus ID|--app STR|--title RE            # focus + verify (records previous)
acu focus --back                             # restore previously focused window
acu spawn --bg -- CMD...                     # launch on "agent" ws, focus preserved
acu spawn --wait -- CMD...                   # launch focused, print new window
acu click [left|right|middle] --window ID --local X,Y [--double]
acu click --at X,Y                           # global logical coords
acu point X Y | acu scroll DY [DX]           # pointer move / scroll at pointer
acu type "text" | acu key ctrl+l mod+Return  # keyboard into FOCUSED window
acu ui --window ID [--find STR]              # AT-SPI elements: id, role, name, window-local extents, actions
acu act --window ID <elem-id> [--set-text S] # invoke element action in-process — NO focus needed
acu restore                                  # epilogue: close overview, refocus
```

`acu key` routes `mod+…` chords through uinput (niri compositor binds ignore virtual-keyboard events); plain chords go to the focused window. `acu ui/act` element ids are per-snapshot index paths — re-run `acu ui` after the UI changes. Chromium's address bar rejects `--set-text`; web form fields and GTK entries accept it.

`--app`/`--title` must match exactly one window; ambiguity lists candidates and fails (use the id).

## Coordinates

- **Window-local** (from `acu shot --window`): what `--local` expects. `acu click --window` maps them to screen exactly — if the window is tiled it is briefly floated to read its true origin (niri only reports positions for floating windows), clicked, then re-tiled. Size is preserved; a size-change warning means re-ground from a fresh shot.
- **Global logical** (from full-desktop shots): what `--at`, `acu point` expect. Single laptop output = eDP-1 2256x1504 at (0,0), scale 1. With external monitors, outputs have offsets (`acu state` shows them) — global = output position + within-output pixel.

## Focus discipline (the top historical failure source)

- **focus-follows-mouse is ON**: any pointer motion over a different window refocuses it. After pointer work, re-assert focus (`acu focus`) before typing. `acu click --window` does this automatically.
- **Keyboard/text always goes to the focused window.** Check `acu state` if in doubt.
- **Seat input cannot reach background windows.** To drive a window you must focus it (its workspace becomes visible). Only CDP apps can be driven invisibly.
- Etiquette: record what you displace, put it back — `acu focus`/`acu spawn --bg` remember the previous focus; end sessions with `acu restore`. If the user starts moving the mouse mid-task, stop and wait.

## Background work ("do it without taking over the desktop")

- `acu spawn --bg -- cmd` opens on the persistent **"agent" workspace** without focus/visibility change. Terminals can be marked (`ghostty --class=acu.<name>`) — `acu.*` app-ids get zero-flicker rules; anything else is moved there right after opening (~0.5s flicker at most, focus still preserved).
- Watch progress: `acu shot --window <id>` — hidden windows screenshot fine.
- Interact invisibly where a semantic channel exists: `acu ui`/`acu act` (AT-SPI) and CDP work on hidden windows without focus. Seat input (click/type/key) still requires focus: batch those bursts, then `acu restore`.
- Hand-off: the user pulls a window to their workspace with `nirius move-to-current-workspace` or workspace nav — same session, windows move freely.

## Known traps → recovery

| Symptom | Cause | Fix |
|---|---|---|
| `focused-window` null, focus actions no-op | Overview is open (stray click on backdrop can open it) | `niri msg action close-overview` — acu does this automatically |
| Click landed nowhere / overview popped | Coordinates guessed, not grounded | Re-shot, use `--grid`, use `--window --local` |
| Typed text went to wrong window | focus-follows-mouse after pointer motion | `acu focus <target>` immediately before typing |
| Clipboard content replaced by a screenshot | Raw `niri msg action screenshot-*` always copies | Use `acu shot` (saves/restores clipboard) |
| New window stole focus from user | Raw `niri msg action spawn` | `acu spawn --bg` |
| wlrctl/wev missing on PATH | Not yet in home.packages | acu resolves via nix-shell and caches; first call is slow |
| Hot corner opens overview on pointer sweeps | Fixed: `gestures { hot-corners { off; } }` in niri config | If it recurs, re-check config reloaded |

## `acu state --json` schema

`overview_open` bool; `focused_window_id`; `outputs[] {name, logical{x,y,width,height,scale}}`; `workspaces[] {id, idx, name, output, is_focused, is_active, active_window_id}`; `windows[] {id, app_id, title, pid, workspace_id, is_focused, is_floating, is_urgent, size[w,h], floating_pos[x,y]|null}`. Note: niri window ids are compositor ids, not PIDs; `floating_pos` is global logical and only present for floating windows.

## References

- `references/environment.md` — this machine's verified environment: protocols, tool paths, config locations, live-reload workflow, CDP endpoints, probe evidence.
- `references/recipes.md` — worked end-to-end examples (background research window, chat-app reading, form filling, app relaunch with CDP).
