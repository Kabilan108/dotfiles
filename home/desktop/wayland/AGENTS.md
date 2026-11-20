# Wayland desktop notes

- Keep `programs.niri.config = null` in `compositors/niri/default.nix`. niri-flake otherwise generates the niri config file from that option, and activation fails on a collision with the hand-written `compositors/niri/config.kdl` symlink.
- `compositors/niri/hosts/sietch.kdl` pins DP-1 (an AOC CU34G2XP ultrawide on the RTX 3090) to 180 Hz, the highest rate the panel offers. If the output comes up black or flickers after a monitor, cable or driver change, add `max-bpc 8` to the output first; only then pin a lower refresh rate from `niri msg outputs`.
- Keep every Dictator call in `swaylock.nix` bounded and non-fatal (`timeout 3`, `|| true`). The lock script releases Dictator's microphone before swaylock and resumes it on exit, and a hung or failing Dictator must never stop the screen from locking.
- The hidden nm-applet and blueman autostart entries in `quickshell/default.nix` exist because Stillsuit provides the network and Bluetooth controls, while the packages stay installed for `nm-connection-editor` and `blueman-manager`. Remove the overrides if Stillsuit stops providing those controls.
