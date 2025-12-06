{ pkgs, ... }:
{
  imports = [
    ./hyprland.nix
    ./waybar.nix
    ./mako.nix
    ./hyprlock.nix
    ./hypridle.nix
    ./walker.nix
  ];

  home.packages = with pkgs; [
    hyprshot
    hyprpicker
    wl-clipboard
    wtype
  ];
}
