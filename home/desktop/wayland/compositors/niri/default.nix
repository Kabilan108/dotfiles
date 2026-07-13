{
  config,
  lib,
  pkgs,
  ...
}:
let
  homeDir = "/home/kabilan";
  agentWorkspacePin = pkgs.writeShellApplication {
    name = "agent-workspace-pin";
    runtimeInputs = [
      pkgs.jq
      pkgs.niri
    ];
    text = builtins.readFile ../../../../../bin/agent-workspace-pin;
  };
in
{
  imports = [
    ../../swaylock.nix
  ];

  home.packages = with pkgs; [
    agentWorkspacePin
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

  systemd.user.services.agent-workspace-pin = {
    Unit = {
      Description = "Keep the niri agent workspace above the trailing empty workspace";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = lib.getExe agentWorkspacePin;
      Restart = "on-failure";
      RestartSec = 1;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
