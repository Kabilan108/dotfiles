{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.mise-update;
in
{
  options.dotfiles.services.mise-update.enable =
    lib.mkEnableOption "weekly mise lock update and push";

  config = lib.mkIf cfg.enable {
    systemd.user.services.mise-update = {
      Unit = {
        Description = "Update, validate, commit and push the mise lock";
        After = [ "network-online.target" ];
        Before = [ "install-tools.service" ];
      };
      Service = {
        Type = "oneshot";
        TimeoutStartSec = "20m";
        Environment = [
          "PATH=${
            lib.makeBinPath [
              pkgs.bash
              pkgs.coreutils
              pkgs.git
              pkgs.mise
              pkgs.openssh
              pkgs.util-linux
            ]
          }"
        ];
        ExecStart = "${pkgs.bash}/bin/bash ${../../bin/mise-update} ${lib.escapeShellArg "${config.home.homeDirectory}/dotfiles"}";
      };
    };
    systemd.user.timers.mise-update = {
      Unit.Description = "Weekly mise lock update";
      Timer = {
        OnCalendar = "Mon *-*-* 03:00:00";
        RandomizedDelaySec = "30m";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
