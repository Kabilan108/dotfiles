{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.meeting-minutes;
  homeDir = config.home.homeDirectory;
  stateDir = "${homeDir}/.local/state/meeting-minutes";
  isJacurutu = osConfig.networking.hostName == "jacurutu";
in
{
  options.dotfiles.services.meeting-minutes.enable =
    lib.mkEnableOption "durable meeting transcription and Coppermind minutes queue";

  config = lib.mkIf cfg.enable {
    systemd.user.services = {
      meeting-minutes-worker = {
        Unit = {
          Description = "Process queued meeting recordings into Coppermind minutes";
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
        };
        Service = {
          Type = "oneshot";
          EnvironmentFile = "/run/agenix/secrets/dictator-env";
          Environment = "MEETING_MINUTES_HARKCTL=${config.home.profileDirectory}/bin/harkctl";
          ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${stateDir}/jobs";
          ExecStart = "${homeDir}/bin/meeting-minutes work";
        };
        Install.WantedBy = [ "default.target" ];
      };

      meeting-minutes-artifact-sync = lib.mkIf isJacurutu {
        Unit = {
          Description = "Copy meeting transcripts and move recordings to Sietch";
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
        };
        Service = {
          Type = "oneshot";
          Environment = [
            "PATH=${
              lib.makeBinPath [
                pkgs.openssh
                pkgs.rsync
              ]
            }"
          ];
          ExecStart = "${lib.getExe pkgs.python3} ${homeDir}/bin/meeting-minutes sync-artifacts";
        };
      };
    };

    systemd.user.paths.meeting-minutes-worker = {
      Unit.Description = "Watch for queued meeting recordings";
      Path.PathChanged = "${stateDir}/jobs";
      Install.WantedBy = [ "default.target" ];
    };

    systemd.user.timers = {
      meeting-minutes-worker = {
        Unit.Description = "Recover missed meeting-minutes queue wakeups";
        Timer = {
          OnBootSec = "2m";
          OnUnitInactiveSec = "2m";
          RandomizedDelaySec = "30s";
        };
        Install.WantedBy = [ "timers.target" ];
      };

      meeting-minutes-artifact-sync = lib.mkIf isJacurutu {
        Unit.Description = "Retry meeting artifact transfer to Sietch";
        Timer = {
          OnBootSec = "5m";
          OnUnitInactiveSec = "5m";
          RandomizedDelaySec = "30s";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
  };
}
