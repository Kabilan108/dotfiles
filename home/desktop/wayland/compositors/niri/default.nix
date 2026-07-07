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

    # agent computer use (agents/skills/niri-computer-use, `acu` CLI):
    # wlrctl = virtual pointer, wev = input-event oracle,
    # dotool = uinput keys for niri compositor binds
    wlrctl
    wev
    dotool
  ];

  xdg.configFile."niri/config.kdl".source =
    config.lib.file.mkOutOfStoreSymlink "${homeDir}/dotfiles/home/desktop/wayland/compositors/niri/config.kdl";
}
