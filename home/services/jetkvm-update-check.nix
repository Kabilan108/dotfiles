{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.jetkvm-update-check;
in
{
  options.dotfiles.services.jetkvm-update-check = {
    enable = lib.mkEnableOption "biweekly JetKVM firmware release check";
    onCalendar = lib.mkOption {
      type = lib.types.str;
      default = "*-*-1,15 10:00:00";
      description = "When to check the public JetKVM release feed.";
    };
    sku = lib.mkOption {
      type = lib.types.str;
      default = "jetkvm-mini-ethernet";
      description = "JetKVM hardware SKU passed to the release feed.";
    };
    hostname = lib.mkOption {
      type = lib.types.str;
      default = "sietch-kvm";
      description = "Tailnet hostname of the JetKVM device.";
    };
    baselineVersion = lib.mkOption {
      type = lib.types.str;
      default = "0.5.20";
      description = "Initial version recorded when no local state file exists yet.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.jetkvm-update-check = {
      Unit = {
        Description = "Check for JetKVM firmware updates and notify via Hark";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        TimeoutStartSec = "2m";
        Environment = [
          "PATH=${
            lib.makeBinPath [
              pkgs.bash
              pkgs.coreutils
              pkgs.curl
              pkgs.jq
            ]
          }:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
        ];
        ExecStart = "${pkgs.bash}/bin/bash ${../../bin/jetkvm-update-check} ${lib.escapeShellArg cfg.sku} ${lib.escapeShellArg cfg.hostname} ${lib.escapeShellArg cfg.baselineVersion}";
      };
    };

    systemd.user.timers.jetkvm-update-check = {
      Unit.Description = "Biweekly JetKVM firmware update check";
      Timer = {
        OnCalendar = cfg.onCalendar;
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
