{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.update-app-pins;
in
{
  options.dotfiles.services.update-app-pins.enable =
    lib.mkEnableOption "daily Helium, ChatGPT desktop and grok-bot pin updates";

  config = lib.mkIf cfg.enable {
    systemd.user.services.update-app-pins = {
      Unit = {
        Description = "Update, build, commit and push the prebuilt app pins";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        TimeoutStartSec = "45m";
        Nice = 10;
        IOSchedulingClass = "idle";
        Environment = [
          "PATH=${
            lib.makeBinPath [
              pkgs.bash
              pkgs.coreutils
              pkgs.curl
              pkgs.dpkg
              pkgs.gh
              pkgs.git
              pkgs.gnupg
              pkgs.jq
              pkgs.openssh
              pkgs.util-linux
            ]
          }:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
        ];
        ExecStart = "${pkgs.bash}/bin/bash ${../../bin/update-app-pins} ${lib.escapeShellArg "${config.home.homeDirectory}/dotfiles"}";
      };
    };

    systemd.user.timers.update-app-pins = {
      Unit.Description = "Daily prebuilt app pin update";
      Timer = {
        OnCalendar = "*-*-* 05:00:00";
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
