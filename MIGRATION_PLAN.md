**Niri Migration Plan (Jacurutu Only)**

Goal: migrate `jacurutu` from Hyprland to niri while keeping `sietch` on Hyprland. Use niri‑native keybindings, keep Waybar common, and use `swayidle`/`swaylock`/`swaybg` + niri built‑in screenshots. Skip color picker for now.

Decisions from discussion
- Compositor stack for niri: `swayidle`, `swaylock`, `swaybg`, niri built‑in screenshots, no color picker.
- Waybar stays in the Wayland base module, but its modules switch per compositor (`hyprland/*` vs `niri/*`).
- Keybindings: niri‑native scheme. `Mod+H/J/K/L` focus, `Mod+Ctrl` moves, `Mod+Shift` focuses monitor, `Mod+Ctrl+Shift` moves column to monitor. `Mod+F` maximize column, `Mod+Shift+F` fullscreen. `Mod+Shift+E` power menu, `Ctrl+Alt+Delete` exit. `Mod+Escape` toggles shortcut‑inhibit.
- Binds must be fully defined in `config.kdl` (no implicit defaults).
- Any bind needing shell expansion must use `spawn-sh`.

Docs to reference (vendored)
- `docs/niri/Configuration:-Key-Bindings.md` (bind syntax, `spawn-sh`, screenshot actions).
- `docs/niri/Integrating-niri.md` (config location, autostart model, Xwayland).
- `docs/niri/Important-Software.md` (portals, auth agent expectations).
- `docs/niri/Workspaces.md` (dynamic workspaces, monitor movement).
- `docs/niri/Tabs.md` (tabbed columns as Hyprland‑style group analog).

---

**Step 1: Integrate niri-flake (with manual KDL config)**
Tasks
- Add `niri-flake` as a flake input and wire its NixOS/HM modules for `jacurutu`.
- Keep the niri configuration as a manually managed `config.kdl` file, exposed via HM `xdg.configFile` so changes hot‑reload.
- Add a brief comment in `flake.nix` near the compositor switch documenting that we use `niri-flake` for caching + packaging while keeping manual config files.

Acceptance
- `niri-flake` is wired for `jacurutu` and `config.kdl` is still managed as a file in this repo.

---

**Step 2: Add Compositor Switch + Folder Structure**
Tasks
- Add `waylandCompositor` argument to `flake.nix` `makeSystem`.
- Pass `waylandCompositor` into `specialArgs` and `home-manager.extraSpecialArgs`.
- Set `waylandCompositor = "hyprland"` for `sietch`, `waylandCompositor = "niri"` for `jacurutu`.
- Create compositor folders:
  - `home/desktop/wayland/compositors/hyprland/`
  - `home/desktop/wayland/compositors/niri/`
- Update `home/desktop/wayland/default.nix` to import the compositor subfolder based on `waylandCompositor`.
- Keep `modules/nixos/desktop-wayland.nix` compositor‑agnostic.

Acceptance
- `home/desktop/wayland/default.nix` is compositor‑agnostic.
- `home/desktop/wayland/compositors/hyprland/default.nix` and `home/desktop/wayland/compositors/niri/default.nix` exist.
- `flake.nix` wires the compositor per host.

---

**Step 3: Waybar Compositor Switch**
Tasks
- Keep `home/desktop/wayland/waybar.nix` in the common Wayland layer.
- Add a compositor switch to use `hyprland/*` modules when `waylandCompositor == "hyprland"` and `niri/*` modules when `waylandCompositor == "niri"`.
- Keep styling and non‑compositor modules unchanged.

Acceptance
- Only the Waybar module names differ per compositor.
- Styling and layout remain the same.

---

**Step 4: Hyprland Modules (HM + NixOS)**
Tasks
- Create `home/desktop/wayland/compositors/hyprland/default.nix` and import:
  - `hyprland.nix`, `hypridle.nix`, `hyprlock.nix`, `hyprpaper.nix`, `hyprshot.nix`, `hyprpicker.nix`
- Move Hyprland‑specific packages out of `home/desktop/wayland/default.nix` into the Hyprland module.
- Create `modules/nixos/wayland/hyprland.nix` and move Hyprland system config there:
  - `programs.hyprland`
  - portal package for Hyprland
  - `security.pam.services.hyprlock`
  - Hyprland cachix settings
- Ensure `modules/nixos/desktop-wayland.nix` is compositor‑agnostic after the move.

Acceptance
- `sietch` still includes Hyprland + tools.
- `jacurutu` no longer pulls Hyprland system config or packages.

---

**Step 5: Niri HM Module + Config**
Tasks
- Create `home/desktop/wayland/compositors/niri/default.nix` with:
  - packages: `swayidle`, `swaylock`, `swaybg`, `xwayland-satellite` (and niri if not provided via module)
  - `xdg.configFile."niri/config.kdl"` pointing at a tracked config file
- Create `home/desktop/wayland/compositors/niri/config.kdl`.
- Start from upstream default `config.kdl` and then modify.
- Use `spawn-sh` for any command needing shell expansion.
- Autostart `mako`, `waybar`, `swaybg`, `swayidle`, `nm-applet`, `blueman-applet`, and `$HOME/dotfiles/bin/battery-watcher` via `spawn-at-startup` or user systemd.
- Ensure `binds {}` is fully defined (no implicit defaults).

Acceptance
- `config.kdl` exists and includes a full `binds {}` block.
- All commands needing `~` or `$(...)` use `spawn-sh`.

---

**Step 6: Niri NixOS Module**
Tasks
- Create `modules/nixos/wayland/niri.nix`.
- Enable or install niri according to Step 1’s decision.
- Add `security.pam.services.swaylock = { }`.
- Ensure portals include `xdg-desktop-portal-gtk` and `xdg-desktop-portal-gnome`.
- Keep `gnome-keyring` enabled (already in base services).
- Ensure `xwayland-satellite` is on PATH.

Acceptance
- Niri module exists with swaylock PAM entry and required portals.
- `jacurutu` no longer depends on Hyprland portal package.

---

**Step 7: Keybindings (Niri‑Native)**
Tasks
- Implement binds in `config.kdl`:
  - `Mod+H/J/K/L`: focus
  - `Mod+Ctrl+H/J/K/L`: move column/window
  - `Mod+Shift+H/J/K/L`: focus monitor
  - `Mod+Ctrl+Shift+H/J/K/L`: move column to monitor
  - `Mod+F`: maximize column
  - `Mod+Shift+F`: fullscreen
  - `Mod+Shift+E`: power menu
  - `Ctrl+Alt+Delete`: exit niri
  - `Mod+Escape`: toggle shortcut‑inhibit
- Replace Hyprland “group” binds with niri consume/expel binds.
- Map screenshots to niri built‑ins:
  - `Print`: interactive screenshot UI
  - `Alt+Print`: window screenshot
  - `Ctrl+Print`: screen screenshot
- Keep launchers:
  - `Mod+Return`: `ghostty`
  - `Mod+Shift+Return`: floating `ghostty` with scratch file (use `spawn-sh`)
  - `Mod+B`: `zen-beta`
  - `Mod+Shift+C`: `google-chrome-stable`

Acceptance
- Binds follow the niri‑native scheme and match the above requirements.
- Power menu is preserved on `Mod+Shift+E`.

---

**Step 8: Verification Checklist**
Tasks
- Verify `sietch` still starts Hyprland and its tools.
- Verify `jacurutu` starts niri with `waybar`, `mako`, `swayidle`, `swaybg`.
- Verify niri screenshots (interactive, window, screen) work.
- Verify X11 apps run via `xwayland-satellite`.
- Verify `Mod+Escape` toggles shortcut‑inhibit.
- Verify Waybar modules switch between `hyprland/*` and `niri/*`.

Acceptance
- All checks pass and `jacurutu` is usable as a daily driver.
