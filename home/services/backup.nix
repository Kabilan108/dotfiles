{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.backup;

  backupJob = pkgs.writeShellScript "backup-weekly-job" ''
    set -eu
    "$HOME/bin/backup" push
    "$HOME/bin/backup" janitor
  '';
in
{
  options.dotfiles.services.backup.enable = lib.mkEnableOption "weekly backup push and janitor";

  config = lib.mkIf cfg.enable {
    systemd.user.services.backup-weekly = {
      Unit = {
        Description = "Weekly backup push and janitor";
        After = "network-online.target";
      };
      Service = {
        Type = "oneshot";
        ExecStart = backupJob;
        Environment = [
          "PATH=%h/bin:${
            pkgs.lib.makeBinPath [
              pkgs.uv
              pkgs.rclone
            ]
          }"
        ];
      };
    };

    systemd.user.timers.backup-weekly = {
      Unit.Description = "Weekly backup run";
      Timer = {
        OnCalendar = "Mon 01:00";
        RandomizedDelaySec = "30m";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
