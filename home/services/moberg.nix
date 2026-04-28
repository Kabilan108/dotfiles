{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.moberg;

  eboostReviewerReport = pkgs.writeShellScript "eboost-reviewer-report" ''
    set -euo pipefail
    cd /vault/work/moberg/dev-server
    source "$HOME/.bashenv"

    ${pkgs.direnv}/bin/direnv exec . \
      eboost-scripts/EBOOST/change-points/scripts/check-eboost-reviewer-progress.sh
  '';
in
{
  options.dotfiles.services.moberg.eboostReviewerReport.enable =
    lib.mkEnableOption "weekly EBOOST reviewer progress report";

  config = lib.mkIf cfg.eboostReviewerReport.enable {
    systemd.user.services.moberg-eboost-reviewer-report = {
      Unit = {
        Description = "Generate EBOOST reviewer progress report";
        After = [ "network-online.target" ];
      };

      Service = {
        Type = "oneshot";
        ExecStart = eboostReviewerReport;
      };
    };

    systemd.user.timers.moberg-eboost-reviewer-report = {
      Unit.Description = "Weekly EBOOST reviewer progress report";
      Timer = {
        OnCalendar = "Mon 11:30";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
