{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.battery-watcher;
  batteryWatcher = pkgs.writeShellApplication {
    name = "battery-watcher";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.libnotify
    ];
    text = builtins.readFile ../../bin/battery-watcher;
  };
in
{
  options.dotfiles.services.battery-watcher.enable =
    lib.mkEnableOption "deduplicated battery notifications";

  config = lib.mkIf cfg.enable {
    home.packages = [ batteryWatcher ];

    systemd.user.services.battery-watcher = {
      Unit = {
        Description = "Check battery alert thresholds";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
        ConditionPathExistsGlob = "/sys/class/power_supply/BAT*";
      };
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe batteryWatcher;
      };
    };

    systemd.user.timers.battery-watcher = {
      Unit = {
        Description = "Check battery alert thresholds every minute";
        PartOf = [ "graphical-session.target" ];
      };
      Timer = {
        OnBootSec = "30s";
        OnUnitActiveSec = "1m";
        RandomizedDelaySec = "5s";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
