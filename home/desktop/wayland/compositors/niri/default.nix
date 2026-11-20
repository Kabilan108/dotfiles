{
  config,
  osConfig,
  pkgs,
  ...
}:
let
  homeDir = "/home/kabilan";
  niriConfigDir = "${homeDir}/dotfiles/home/desktop/wayland/compositors/niri";
in
{
  imports = [
    ../../swaylock.nix
  ];

  home.packages = with pkgs; [
    swayidle
    swaybg
    xwayland-satellite

    wlrctl
    wev
    dotool
    grim
  ];

  programs.niri.config = null;

  xdg.configFile."niri/config.kdl".source =
    config.lib.file.mkOutOfStoreSymlink "${niriConfigDir}/config.kdl";

  xdg.configFile."niri/host.kdl".source =
    config.lib.file.mkOutOfStoreSymlink "${niriConfigDir}/hosts/${osConfig.networking.hostName}.kdl";
}
