# Verified environment (2026-07-07, niri unstable 2026-06-08)

Everything below was probed live on this machine; re-verify with `acu doctor` at session start.

## Display & compositor

- Laptop output `eDP-1`: 2256x1504 logical, scale 1.0, position (0,0). External monitors (`DP-2`, `DP-4`) are configured in the niri config with offsets — when connected, global coordinates include their positions (`acu state` shows the live layout).
- niri config: `~/.config/niri/config.kdl` → out-of-store symlink → `~/dotfiles/home/desktop/wayland/compositors/niri/config.kdl`. **Live-editable**: edit, `niri validate`, then `niri msg action load-config-file` (niri also auto-reloads on save). No home-manager rebuild needed.
- Named workspace `"agent"` is declared in config (persistent background staging area).
- Window rule: `app-id ^acu\.` → `open-on-workspace "agent"` + `open-focused false` (zero-flicker background spawns for marked apps).
- Hot corners are DISABLED in config (`gestures { hot-corners { off; } }`) because synthetic pointer sweeps through (0,0) kept opening the overview. Overview is still on Mod+O.
- `focus-follows-mouse max-scroll-amount="0%"` is enabled — pointer motion over a fully-visible window focuses it.
- Top layer surfaces: waybar + stillsuit-bar (quickshell). Floating windows clamp to y >= ~290 in the working area. Layer surfaces expose no geometry via IPC on this build.
- `prefer-no-csd`, gaps 6, default column width 0.5.

## Input protocols (Wayland-native — the only reliable path)

- niri implements `zwlr_virtual_pointer_manager_v1` v2 and `zwp_virtual_keyboard_manager_v1` v1 (verified via wayland-info).
- **Pointer: wlrctl** — `pointer move DX DY` (relative), `pointer click left|right|middle`, `pointer scroll DY DX`. Absolute positioning = clamp trick: move `-20000 -20000` (pointer clamps to (0,0)) then move `X Y`. Verified pixel-exact against wev.
- **Keyboard: wtype** — text as argv, `-k <XKB name>` for keys, `-M/-m` for modifier press/release (`logo` = Super/Mod). Uploads its own keymap per call; reliable.
- **Do NOT use uinput tools** (ydotool/dotool): button/key events work but pointer motion silently failed in live probing (ydotool absolute uses non-pixel scaling; motions dropped). ydotoold runs as a user service but acu does not need it.
- `wlrctl window list|focus|...` also works (foreign-toplevel) — app-id/title based, no window ids.
- XWayland: xwayland-satellite provides DISPLAY=:0; xdotool (not installed) could drive X11 clients per-window — niche, untested.
- AT-SPI accessibility bus is running and niri registers `org.freedesktop.a11y.Manager` — see "AT-SPI semantic channel" below.

## Screenshots

- `niri msg action screenshot-window --id N` captures ANY window — hidden workspaces included — in window-local pixels, without changing focus. Writes to `~/media/screenshots/<timestamp>.png` (config `screenshot-path`) AND replaces the clipboard. `acu shot` wraps it: relocates the file, preserves the clipboard, prints dimensions.
- `grim` captures outputs/regions in global logical coordinates (`-o eDP-1`, `-g "x,y WxH"`).
- Never open `niri msg action screenshot` (interactive UI).

## Window geometry

- Tiled windows report `layout.tile_pos_in_workspace_view = null` on this build — no on-screen rect via IPC.
- **Floating windows report exact position** in `tile_pos_in_workspace_view` (post-clamping). `move-floating-window --id N -x X -y Y` sets absolute position (clamped to working area; read back for truth).
- This is why `acu click --window` floats a tiled window briefly: float preserves the window's size, gives an exact origin, then re-tiles. (Fullscreen would resize and invalidate grounded coordinates.)

## Useful compositor actions (beyond acu)

- `move-window-to-workspace --window-id N --focus false <ref>` — move without focus; focus auto-returns if the moved window had it.
- `close-window --id N`, `focus-window --id N`, `fullscreen-window --id N`, `toggle-window-floating --id N`.
- `niri msg event-stream` — live window/workspace/focus events (Rust debug format, not JSON).
- `niri msg pick-window` / `pick-color` — interactive (user must click), not for agents.
- nirius daemon: `nirius focus-or-spawn`, `move-to-current-workspace`, marks, scratchpad.

## App landscape

- **helium** (Chromium): permanent CDP at 127.0.0.1:9222; `HeliumAgentsDevTools` profile/window exists for agent work (has its own no-focus window rule). Drive with `agent-browser`.
- **zen-beta** (Firefox): no CDP; GUI loop or keyboard-driven.
- **Electron**: Discord, Slack, obsidian, t3code — CDP only if relaunched with `--remote-debugging-port=<port>`; that also exposes the app to any local process (loopback), so treat as opt-in.
- **ghostty**: supports `--class=<app-id>` (marker app-ids for window rules) and `--title=...`; user works in tmux inside it — prefer tmux for terminal content.
- Spotify: `playerctl`. Quickshell bar: `qs ipc -c stillsuit call ...`, `stillctl`.

## Verification oracles (for testing input paths)

- `wev` window (spawn with `stdbuf -oL wev > log`) logs enter/motion/button/key events with surface-local coordinates — the ground truth for input delivery.
- Terminal mouse-reporting (SGR 1003/1006) is a MISLEADING oracle: line buffering and cell quantization produced false negatives in probing. Don't debug input with it.

## AT-SPI semantic channel (verified 2026-07-07)

- The a11y bus runs; niri registers org.freedesktop.a11y.Manager. Slack, Discord,
  helium, Chromium, Zen, t3code all REGISTER on the bus, but Chromium/Electron
  trees stay dormant (3 nodes) unless accessibility was enabled at launch.
- Enabler (now in niri config spawn-at-startup): set the session screen-reader flag
  `busctl --user set-property org.a11y.Bus /org/a11y/bus org.a11y.Status ScreenReaderEnabled b true`
  — apps launched AFTER it build full trees. Per-app alternative: `--force-renderer-accessibility`.
  Verified: fresh helium instance exposed 178 named nodes (buttons, address bar, web content).
- `acu ui` extents use AT-SPI WINDOW_COORDS — same space as `acu shot --window` pixels.
- `acu act <id>` invokes Action.doAction in-process: verified button press with zero
  focus/pointer involvement, window on a hidden workspace. `--set-text` works via
  EditableText (Chromium omnibox rejects it; web form fields/GTK entries accept).
- pyatspi env resolves via nix-shell (at-spi2-core + gobject-introspection +
  python3.withPackages pyatspi/pygobject3), cached in ~/.cache/acu/tools.json.
