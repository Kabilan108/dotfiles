# Sietch on niri: follow-up handoff

Read this before changing sietch's desktop setup. It records the state as of October 6, 2026, after the `niri-sietch` work was merged into `nixos` at `08559b2e`. Recheck runtime state before acting.

Update, October 26, 2026: Hyprland is gone from both hosts, along with waybar, mako, walker and elephant. To bring it back as a gaming session, start from the commit that deleted it: `git log --diff-filter=D -1 -- modules/nixos/wayland/hyprland.nix`.

## Where things stand

- sietch runs niri. `~/.bashrc` execs `niri-session` on tty1.
- Both hosts run niri only. Stillsuit's unit still requires `XDG_CURRENT_DESKTOP=niri`.
- Per-host niri settings live in `home/desktop/wayland/compositors/niri/hosts/<host>.kdl`, included as `~/.config/niri/host.kdl`. sietch's file pins DP-1 to 3440x1440 @ 180 Hz and forces shared-memory screencasting.
- niri-unstable is overridden to track `github:niri-wm/niri` directly (niri-flake stopped bumping its pin in August 2026). niri is at 2026-10-01 (`ed22699d`). These builds are not in niri-flake's cache, so updates compile locally. The current build is pushed to `kabilan108.cachix.org`.

Verified on sietch: 180 Hz, Stillsuit bar, notifications, niri under ~135 MiB VRAM, wayvnc from jacurutu, lock/idle/unlock, screen sharing from Helium (window and entire screen), clicking workspace numbers.

## Open items

1. **Roll out to jacurutu.** Pull `nixos` and rebuild right away. Until it rebuilds, niri there reloads the new `config.kdl` without `host.kdl` and its monitors fall back to automatic placement. Log out and back in afterwards so the new niri starts. niri should come from Cachix rather than compiling.
2. **Gaming on niri.** Untested. Try one Proton game and Minecraft. The concern is freezes on the NVIDIA driver without explicit sync. If they fail, restore Hyprland from git history as a bare gaming session: no waybar or mako, just enough to launch Steam. Never run it alongside niri: both share the user manager's single `graphical-session.target`, so starting one tears down the other.
3. **VRR.** niri reports "Variable refresh rate: not supported" on DP-1. Turn on FreeSync in the monitor's menu, then check `niri msg outputs`. Only matters for games.
4. **Cachix after niri updates.** Each niri bump compiles locally. Push the new niri store path with `cachix push kabilan108 <path>` so jacurutu downloads it, or automate that step.
5. **d4-widgets test failure.** `src/tests/d4-widgets/run-fixtures.sh` in the Stillsuit shell fails at the recording plugin's `routeActions` check (returns `[]`, expects `["stillsuit.recording"]`). It predates the niri work. Handed to T3 thread `mcp:d71f74c6-da08-4041-a610-888a5e0fa8c7` on branch `fix/d4-widgets-route-actions`.

## Screen sharing on NVIDIA

Helium answers niri's dmabuf offer with a single invalid modifier. niri only accepts a list of alternatives at that step, so it stopped the cast (`wrong modifier choice type`). That rejection is still in niri's 2026-10-01 code. The `force-pipewire-invalid-modifier` debug option gets past negotiation, but the NVIDIA driver cannot render into an invalid-modifier buffer (`EGLImage not supported`), so the call shows a blank share. What works is `disable-pipewire-dmabuf` in `hosts/sietch.kdl`, which makes niri offer only shared-memory buffers; it costs a CPU copy per frame. Revisit if a later niri accepts a single-value modifier.
