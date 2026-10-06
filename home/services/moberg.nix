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
    export PATH="${lib.makeBinPath [ pkgs.curl ]}:$PATH"

    exec ${pkgs.direnv}/bin/direnv exec . \
      ${lib.escapeShellArg eboostReviewerReportScript} preview --notify
  '';

  devMaintenance = pkgs.writeShellScript "moberg-dev-maintenance" ''
    set -euo pipefail
    cd ${lib.escapeShellArg cfg.devMaintenance.checkout}
    source "$HOME/.bashenv"
    ${lib.optionalString (cfg.devMaintenance.dockerHost != null) ''
      export DEV_DOCKER_HOST=${lib.escapeShellArg cfg.devMaintenance.dockerHost}
      export DOCKER_HOST="$DEV_DOCKER_HOST"
      unset DOCKER_CONTEXT
    ''}
    exec ${pkgs.direnv}/bin/direnv exec . "$@"
  '';

  # Runs the checkout's editable devcli venv directly: a forced SSH command has
  # no login environment, and loading the direnv/nix shell would cost seconds
  # per poll. Docker's endpoint comes from ~/.config/moberg/docker.toml.
  devStatus = pkgs.writeShellApplication {
    name = "moberg-dev-status";
    runtimeInputs = [
      pkgs.git
      pkgs.coreutils
    ];
    text = ''
      export PATH="$PATH:/run/current-system/sw/bin"
      cd ${lib.escapeShellArg cfg.devStatus.checkout}
      exec timeout 20 ./.cache/devcli/bin/dev co list --json
    '';
  };
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
      dockerHost = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Explicit rootless Docker endpoint for development maintenance";
      };
    };

    devStatus = {
      enable = lib.mkEnableOption "moberg-dev-status, the read-only checkout status command used by the desktop dev-checkouts plugin";
      checkout = lib.mkOption {
        type = lib.types.str;
        default = "/vault/work/moberg/dev-server";
        description = "Checkout whose devcli venv lists all attached checkouts";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.devStatus.enable {
      home.packages = [ devStatus ];
    })
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
            Requires = lib.mkIf (cfg.devMaintenance.dockerHost != null) [ "docker.service" ];
            After = lib.mkIf (cfg.devMaintenance.dockerHost != null) [ "docker.service" ];
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
