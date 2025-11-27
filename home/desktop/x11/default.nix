{ pkgs, ... }:
{
  imports = [
    ./betterlockscreen.nix
    ./dunst.nix
    ./i3.nix
    ./picom.nix
    ./polybar.nix
    ./rofi
  ];

  home.file.".config/greenclip.toml".source = ../../../config/greenclip.toml;

  home.packages = with pkgs; [
    arandr
    autorandr
    betterlockscreen
    dunst
    feh # display agnostic?
    flameshot
    picom
    rofi
    xclip
    xdotool
    xorg.xdpyinfo
    xorg.xev
    xorg.xrandr
  ];
}
