{ pkgs, config, ... }:
let
  homeDir = "/home/kabilan";
in
{
  home.packages = [ pkgs.quickshell ];

  xdg.configFile."quickshell/osd".source =
    config.lib.file.mkOutOfStoreSymlink
      "${homeDir}/dotfiles/home/desktop/wayland/quickshell/osd";
}
