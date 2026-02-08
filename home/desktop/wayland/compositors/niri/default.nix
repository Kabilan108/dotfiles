{ pkgs, config, ... }:
let
  homeDir = "/home/kabilan";
in
{
  imports = [
    ../../swaylock.nix
  ];

  home.packages = with pkgs; [
    swayidle
    swaybg
    xwayland-satellite
  ];

  xdg.configFile."niri/config.kdl".source =
    config.lib.file.mkOutOfStoreSymlink "${homeDir}/dotfiles/home/desktop/wayland/compositors/niri/config.kdl";
}
