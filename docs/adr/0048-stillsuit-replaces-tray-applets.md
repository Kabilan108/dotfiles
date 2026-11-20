# Hide nm-applet and blueman tray applets under Stillsuit

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Stillsuit provides the network and Bluetooth controls. The NetworkManager and blueman packages are still wanted for their manager commands (`nm-connection-editor`, `blueman-manager`), but their XDG autostart entries start legacy tray applets.

## Decision

The quickshell home module writes `autostart/nm-applet.desktop` and `autostart/blueman.desktop` with `Hidden=true`, keeping the packages but suppressing the applets.

## Consequences

If Stillsuit stops providing network or Bluetooth controls, remove the overrides.

## Where

- `home/desktop/wayland/quickshell/default.nix` (`xdg.configFile."autostart/nm-applet.desktop"`, `xdg.configFile."autostart/blueman.desktop"`)
