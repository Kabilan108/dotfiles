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

  # The forced command behind the desktop dev-checkouts key. It accepts only
  # `status`, `pause NAME`, and `resume NAME`, from SSH_ORIGINAL_COMMAND or
  # argv. It runs the checkout's editable devcli venv directly: a forced SSH
  # command has no login environment, and loading the direnv/nix shell would
  # cost seconds per poll. Docker's endpoint comes from ~/.config/moberg/docker.toml.
  devCheckouts = pkgs.writeShellApplication {
    name = "moberg-dev-checkouts";
    runtimeInputs = [
      pkgs.git
      pkgs.coreutils
    ];
    text = ''
      export PATH="$PATH:/run/current-system/sw/bin"
      usage() {
        printf 'usage: moberg-dev-checkouts [status | pause NAME | resume NAME]\n' >&2
        exit 2
      }
      read -r -a words <<<"''${SSH_ORIGINAL_COMMAND-$*}"
      verb="''${words[0]:-status}"
      cd ${lib.escapeShellArg cfg.devCheckouts.checkout}
      dev=./.cache/devcli/bin/dev
      case "$verb" in
        status)
          [[ ''${#words[@]} -le 1 ]] || usage
          exec timeout 20 "$dev" co list --json
          ;;
        pause | resume)
          [[ ''${#words[@]} -eq 2 && ''${words[1]} =~ ^[a-z0-9][a-z0-9._-]*$ ]] || usage
          limit=120
          [[ $verb == resume ]] && limit=900
          exec timeout "$limit" "$dev" --checkout "''${words[1]}" co "$verb" --json
          ;;
        *) usage ;;
      esac
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

    devCheckouts = {
      enable = lib.mkEnableOption "moberg-dev-checkouts, the status/pause/resume command used by the desktop dev-checkouts plugin";
      checkout = lib.mkOption {
        type = lib.types.str;
        default = "/vault/work/moberg/dev-server";
        description = "Checkout whose devcli venv lists all attached checkouts";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.devCheckouts.enable {
      home.packages = [ devCheckouts ];
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
