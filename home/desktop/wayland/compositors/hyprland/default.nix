{ lib, ... }:
let
  # Hosts can run niri and Hyprland from the same user manager, where every
  # graphical-session.target unit would start under both compositors. mako is
  # also D-Bus activated and would otherwise claim org.freedesktop.Notifications
  # ahead of Stillsuit in a niri session. Drop-ins keep each unit's own conditions.
  hyprlandSessionUnits = [
    "waybar"
    "hyprpaper"
    "mako"
  ];
in
{
  imports = [
    ../../hyprland.nix
    ../../hyprpaper.nix
    ../../hyprshot.nix
    ../../hyprpicker.nix
    ../../swaylock.nix
    ../../mako.nix
    ../../waybar.nix
  ];

  xdg.configFile = lib.listToAttrs (
    map (
      unit:
      lib.nameValuePair "systemd/user/${unit}.service.d/hyprland-session-only.conf" {
        text = ''
          [Unit]
          ConditionEnvironment=XDG_CURRENT_DESKTOP=Hyprland
        '';
      }
    ) hyprlandSessionUnits
  );
}
