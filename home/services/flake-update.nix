{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.flake-update;
  homeDir = config.home.homeDirectory;
in
{
  options.dotfiles.services.flake-update = {
    enable = lib.mkEnableOption "weekly flake update PR (sietch only)";
    onCalendar = lib.mkOption {
      type = lib.types.str;
      default = "Sat 04:00";
      description = "When to update the locks, build, and open the PR.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.flake-update = {
      Unit = {
        Description = "Update flake inputs, build the hosts, and open a PR";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        # Three builds of up to 3h each when caches miss (BUILD_TIMEOUT in the script).
        TimeoutStartSec = "10h";
        Nice = 10;
        Environment = [
          "PATH=${
            lib.makeBinPath [
              pkgs.coreutils
              pkgs.gh
              pkgs.git
              pkgs.openssh
            ]
          }:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
        ];
        # A store copy, so the job doesn't run whatever ~/dotfiles has checked out.
        ExecStart = "${lib.getExe pkgs.python3} ${../../bin/flake-update-pr} --repo-dir ${homeDir}/dotfiles";
      };
    };

    systemd.user.timers.flake-update = {
      Unit.Description = "Weekly flake update PR";
      Timer = {
        OnCalendar = cfg.onCalendar;
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
