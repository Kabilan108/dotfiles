{ pkgs, config, ... }:
let
  homeDir = "/home/kabilan";
in
{
  home.packages = with pkgs; [
    swayidle
    swaylock
    swaybg
    xwayland-satellite
  ];

  # xdg.configFile."niri/config.kdl".source =
  #   config.lib.file.mkOutOfStoreSymlink "${homeDir}/dotfiles/home/desktop/wayland/compositors/niri/config.kdl";
}
