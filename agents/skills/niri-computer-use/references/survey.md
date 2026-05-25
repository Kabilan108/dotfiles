# Local Survey

Environment observed on 2026-05-25:

- `XDG_SESSION_TYPE=wayland`
- `WAYLAND_DISPLAY=wayland-1`
- `DISPLAY=:0`
- niri CLI and compositor version: `unstable 2026-05-21`, commit `4294948cf1c70c50e938383c2c865d7ca455ac7e`
- Output: `eDP-1`, logical `2256x1504` at scale `1.0`
- Layers: `wallpaper` background and `waybar` top
- Keyboard layouts: `English (US)`

Available directly on `PATH`:

- `niri`
- `wtype`
- `wl-copy`
- `jq`
- `magick`

Fetched successfully with `nix-shell -p`:

- `grim`
- `slurp`
- `dotool`
- `ydotool`
- `wev`
- `wlrctl`

Known-good probes:

- `nix-shell -p grim imagemagick --run 'tmp=$(mktemp --suffix=.png); grim "$tmp" && identify -format "%w %h %m\n" "$tmp"; rm -f "$tmp"'` produced `2256 1504 PNG`.
- `niri msg action focus-column-left` changed focus from window id `5` to `7`; `niri msg action focus-window --id 5` restored focus.
- `nix-shell -p dotool --run 'printf "mousemove 1 0\n" | dotool'` exited successfully.
- `scripts/acu-input key super+o` toggled niri overview from `{"is_open":false}` to `{"is_open":true}`, confirming desktop-level niri shortcuts can be sent through `dotool`.
- The audio mixer binding in `home/desktop/wayland/compositors/niri/config.kdl` is `Mod+A`, which maps to `scripts/acu-input shortcut mod+a` or `scripts/acu-input key super+a`.

Problem probes:

- `nix-shell -p ydotool --run 'ydotool mousemove 1 0'` failed because `/run/user/1000/.ydotool_socket` did not exist.
- `nix-shell -p wlrctl --run 'wlrctl pointer'` segfaulted.
- `nix-shell -p libnotify --run notify-send` hit a symbol lookup error in this mixed environment. Use the system `notify-send` if present instead of fetching `libnotify` ad hoc.
