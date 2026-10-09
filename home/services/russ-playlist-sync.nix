{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.russ-playlist-sync;
  script = ../../bin/russ-playlist-sync;
in
{
  options.dotfiles.services.russ-playlist-sync.enable =
    lib.mkEnableOption "weekly Russ playlist updates through Executor";

  config = lib.mkIf cfg.enable {
    # Take over the two units installed directly before the next user rebuild.
    xdg.configFile."systemd/user/russ-playlist-sync.service".force = true;
    xdg.configFile."systemd/user/russ-playlist-sync.timer".force = true;
    assertions = [
      {
        assertion = osConfig.networking.hostName == "sietch";
        message = "Run russ-playlist-sync on only Sietch to keep one removal history.";
      }
    ];
    systemd.user.services.russ-playlist-sync = {
      Unit.Description = "Add new Russ releases to Spotify through Executor";
      Service = {
        Type = "oneshot";
        LoadCredential = "executor-api-key:%h/.config/russ-playlist-sync/executor-env";
        ExecStart = "${lib.getExe pkgs.python3} ${script} --apply";
        TimeoutStartSec = "15min";
        UMask = "0077";
        NoNewPrivileges = true;
      };
    };
    systemd.user.timers.russ-playlist-sync = {
      Unit.Description = "Weekly Russ playlist update";
      Timer = {
        OnCalendar = "Sat *-*-* 12:00:00 UTC";
        RandomizedDelaySec = "30min";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
