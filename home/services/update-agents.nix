{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.update-agents;

  updateAgents = pkgs.writeShellScript "update-agents" ''
    set -euo pipefail
    source "$HOME/.bashenv"

    amp update
    opencode upgrade
    codex update
    pi update
    claude upgrade
  '';
in
{
  options.dotfiles.services.update-agents.enable = lib.mkEnableOption "Agent CLI updates";

  config = lib.mkIf cfg.enable {
    systemd.user.services.update-agents = {
      Unit = {
        Description = "Update Agent CLIs";
        After = "network-online.target";
      };
      Service = {
        Type = "oneshot";
        ExecStart = updateAgents;
      };
      Install.WantedBy = [ "default.target" ];
    };

    systemd.user.timers.update-agents = {
      Unit.Description = "Daily update of Agent CLIs";
      Timer = {
        OnBootSec = "5m";
        OnUnitActiveSec = "24h";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
