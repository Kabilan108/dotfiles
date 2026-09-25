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

    # agent computer use (agents/skills/niri-computer-use, `acu` CLI):
    # wlrctl = virtual pointer, wev = input-event oracle,
    # dotool = uinput keys for niri compositor binds
    wlrctl
    wev
    dotool
  ];

  # niri-flake would otherwise generate config.kdl and collide with the symlink below.
  programs.niri.config = null;

  xdg.configFile."niri/config.kdl".source =
    config.lib.file.mkOutOfStoreSymlink "${niriConfigDir}/config.kdl";

  # config.kdl includes this for outputs and anything else that differs per machine.
  xdg.configFile."niri/host.kdl".source =
    config.lib.file.mkOutOfStoreSymlink "${niriConfigDir}/hosts/${osConfig.networking.hostName}.kdl";
}
