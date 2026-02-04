{ pkgs, ... }:
{
  home.packages = with pkgs; [
    swayidle
    swaylock
    swaybg
    xwayland-satellite
  ];

  xdg.configFile."niri/config.kdl".source = ./config.kdl;
}
