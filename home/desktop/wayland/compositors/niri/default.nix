{
  config,
  osConfig,
  pkgs,
  ...
}:
let
  homeDir = "/home/kabilan";
  niriConfigDir = "${homeDir}/dotfiles/home/desktop/wayland/compositors/niri";
  acuTools = with pkgs; [
    wlrctl
    wev
    dotool
    grim
  ];
in
{
  imports = [
    ../../swaylock.nix
  ];

  home.packages =
    with pkgs;
    [
      swayidle
      swaybg
      xwayland-satellite
    ]
    ++ acuTools;

  programs.niri.config = null;

  xdg.configFile."niri/config.kdl".source =
    config.lib.file.mkOutOfStoreSymlink "${niriConfigDir}/config.kdl";

  xdg.configFile."niri/host.kdl".source =
    config.lib.file.mkOutOfStoreSymlink "${niriConfigDir}/hosts/${osConfig.networking.hostName}.kdl";
}
