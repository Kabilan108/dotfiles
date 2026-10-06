# Sietch on niri: follow-up handoff

Read this before changing sietch's desktop setup or deciding whether to drop Hyprland there. It records the state as of October 6, 2026, after the `niri-sietch` work was merged into `nixos` at `08559b2e`. Recheck runtime state before acting.

## Where things stand

- sietch runs niri by default. `~/.bashrc` execs `niri-session` on tty1 whenever it is installed. Hyprland is still installed as a fallback for gaming.
- `flake.nix` lists compositors per host: sietch has `[ "niri" "hyprland" ]`, jacurutu has `[ "niri" ]`. Session services are gated on `XDG_CURRENT_DESKTOP`: Stillsuit only starts under niri; waybar, hyprpaper and mako only under Hyprland.
- Per-host niri settings live in `home/desktop/wayland/compositors/niri/hosts/<host>.kdl`, included as `~/.config/niri/host.kdl`. sietch's file pins DP-1 to 3440x1440 @ 180 Hz and forces shared-memory screencasting.
- niri-unstable is overridden to track `github:niri-wm/niri` directly (niri-flake stopped bumping its pin in August 2026). niri is at 2026-10-01 (`ed22699d`). These builds are not in niri-flake's cache, so updates compile locally. The current build is pushed to `kabilan108.cachix.org`.

Verified on sietch: 180 Hz, Stillsuit bar, notifications, niri under ~135 MiB VRAM, wayvnc from jacurutu, lock/idle/unlock, screen sharing from Helium (window and entire screen), clicking workspace numbers.

## Open items

1. **Roll out to jacurutu.** Pull `nixos` and rebuild right away. Until it rebuilds, niri there reloads the new `config.kdl` without `host.kdl` and its monitors fall back to automatic placement. Log out and back in afterwards so the new niri starts. niri should come from Cachix rather than compiling.
2. **Gaming on niri.** Untested. Try one Proton game and Minecraft. The concern is freezes on the NVIDIA driver without explicit sync.
   - If they work, remove Hyprland from sietch (`waylandCompositors` in `flake.nix`) and the Hyprland-only gating it no longer needs.
   - If they don't, keep Hyprland as a bare gaming session: no waybar or mako, just enough to launch Steam.
3. **A clean Hyprland session.** Not yet seen working. Log out of niri first, then log in on tty2 and run `Hyprland`; expect waybar and hyprpaper, and no Stillsuit. Never start Hyprland while niri is still running: both share the user manager's single `graphical-session.target`, so starting one tears down the other, and niri's shutdown then stops Hyprland's session too. That is what happened on October 6 and why the bar was missing.
4. **VRR.** niri reports "Variable refresh rate: not supported" on DP-1. Turn on FreeSync in the monitor's menu, then check `niri msg outputs`. Only matters for games.
5. **Cachix after niri updates.** Each niri bump compiles locally. Push the new niri store path with `cachix push kabilan108 <path>` so jacurutu downloads it, or automate that step.
6. **d4-widgets test failure.** `src/tests/d4-widgets/run-fixtures.sh` in the Stillsuit shell fails at the recording plugin's `routeActions` check (returns `[]`, expects `["stillsuit.recording"]`). It predates the niri work. Handed to T3 thread `mcp:d71f74c6-da08-4041-a610-888a5e0fa8c7` on branch `fix/d4-widgets-route-actions`.

## Screen sharing on NVIDIA

Helium answers niri's dmabuf offer with a single invalid modifier. niri only accepts a list of alternatives at that step, so it stopped the cast (`wrong modifier choice type`). That rejection is still in niri's 2026-10-01 code. The `force-pipewire-invalid-modifier` debug option gets past negotiation, but the NVIDIA driver cannot render into an invalid-modifier buffer (`EGLImage not supported`), so the call shows a blank share. What works is `disable-pipewire-dmabuf` in `hosts/sietch.kdl`, which makes niri offer only shared-memory buffers; it costs a CPU copy per frame. Revisit if a later niri accepts a single-value modifier.
