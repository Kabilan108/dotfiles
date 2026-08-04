{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.meeting-minutes;
  homeDir = config.home.homeDirectory;
  stateDir = "${homeDir}/.local/state/meeting-minutes";
in
{
  options.dotfiles.services.meeting-minutes.enable =
    lib.mkEnableOption "durable meeting transcription and Coppermind minutes queue";

  config = lib.mkIf cfg.enable {
    systemd.user.services.meeting-minutes-worker = {
      Unit = {
        Description = "Process queued meeting recordings into Coppermind minutes";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        EnvironmentFile = "/run/agenix/secrets/dictator-env";
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${stateDir}/jobs";
        ExecStart = "${homeDir}/bin/meeting-minutes work";
      };
      Install.WantedBy = [ "default.target" ];
    };

    systemd.user.paths.meeting-minutes-worker = {
      Unit.Description = "Watch for queued meeting recordings";
      Path.PathChanged = "${stateDir}/jobs";
      Install.WantedBy = [ "default.target" ];
    };

    systemd.user.timers.meeting-minutes-worker = {
      Unit.Description = "Recover missed meeting-minutes queue wakeups";
      Timer = {
        OnBootSec = "2m";
        OnUnitInactiveSec = "2m";
        RandomizedDelaySec = "30s";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
