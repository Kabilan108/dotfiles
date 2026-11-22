{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  homeDir = "/home/kabilan";
  niriConfigDir = "${homeDir}/dotfiles/home/desktop/wayland/compositors/niri";
  niriToggleOutput = pkgs.writeShellScriptBin "niri-toggle-output" ''
    set -euo pipefail
    target="''${1:?usage: niri-toggle-output OUTPUT [FALLBACK_OUTPUT]}"
    fallback="''${2:-}"
    outputs=$(niri msg --json outputs)

    if ${lib.getExe pkgs.jq} -e --arg out "$target" '.[$out].logical != null' <<< "$outputs" >/dev/null; then
      if [ -n "$fallback" ] && ! ${lib.getExe pkgs.jq} -e --arg out "$fallback" '.[$out].logical != null' <<< "$outputs" >/dev/null; then
        exit 0
      fi
      niri msg output "$target" off
    else
      niri msg output "$target" on
    fi
  '';
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
      niriToggleOutput
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
