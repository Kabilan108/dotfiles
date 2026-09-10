{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.moberg;
  devServerCheckout = "/vault/work/moberg/dev-server";
  eboostReviewerReportScript = "${devServerCheckout}/eboost-scripts/EBOOST/change-points/scripts/eboost-review-report.py";

  eboostReviewerReport = pkgs.writeShellScript "eboost-reviewer-report" ''
    set -euo pipefail
    cd ${lib.escapeShellArg devServerCheckout}
    source "$HOME/.bashenv"

    exec ${pkgs.direnv}/bin/direnv exec . \
      ${lib.escapeShellArg eboostReviewerReportScript} preview --notify
  '';

  devMaintenance = pkgs.writeShellScript "moberg-dev-maintenance" ''
    set -euo pipefail
    cd ${lib.escapeShellArg cfg.devMaintenance.checkout}
    source "$HOME/.bashenv"
    exec ${pkgs.direnv}/bin/direnv exec . "$@"
  '';
in
{
  options.dotfiles.services.moberg = {
    eboostReviewerReport.enable = lib.mkEnableOption "weekly EBOOST reviewer progress report";

    devMaintenance = {
      enable = lib.mkEnableOption "Moberg dev checkout garbage collection and Git fetch timers";
      checkout = lib.mkOption {
        type = lib.types.str;
        default = "/vault/work/moberg/dev-server";
        description = "Primary dev-server checkout used to invoke the maintenance CLI";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.eboostReviewerReport.enable {
      systemd.user.services.moberg-eboost-reviewer-report = {
        Unit = {
          Description = "Prepare EBOOST weekly reviewer report preview";
          After = [ "network-online.target" ];
          ConditionPathExists = eboostReviewerReportScript;
        };

        Service = {
          Type = "oneshot";
          ExecStart = eboostReviewerReport;
        };
      };

      systemd.user.timers.moberg-eboost-reviewer-report = {
        Unit.Description = "Prepare weekly EBOOST reviewer report preview";
        Timer = {
          OnCalendar = "Mon *-*-* 09:00:00 America/New_York";
          RandomizedDelaySec = "5m";
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    })
    (lib.mkIf cfg.devMaintenance.enable {
      systemd.user.services = {
        moberg-dev-gc = {
          Unit = {
            Description = "Stop idle Moberg development containers";
            ConditionPathExists = cfg.devMaintenance.checkout;
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${devMaintenance} dev gc --idle 12h --json";
          };
        };

        moberg-dev-fetch = {
          Unit = {
            Description = "Fetch Moberg development repositories";
            ConditionPathExists = cfg.devMaintenance.checkout;
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${devMaintenance} dev git fetch --all --quiet";
          };
        };
      };

      systemd.user.timers = {
        moberg-dev-gc = {
          Unit.Description = "Hourly Moberg development container idle check";
          Timer = {
            OnCalendar = "*-*-* *:23:00";
            RandomizedDelaySec = "5m";
            Persistent = true;
          };
          Install.WantedBy = [ "timers.target" ];
        };

        moberg-dev-fetch = {
          Unit.Description = "Fetch Moberg development repositories three times daily";
          Timer = {
            OnCalendar = "*-*-* 03,11,19:17:00";
            RandomizedDelaySec = "10m";
            Persistent = true;
          };
          Install.WantedBy = [ "timers.target" ];
        };
      };
    })
  ];
}
