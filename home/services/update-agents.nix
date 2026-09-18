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

    failures=()
    update_agent() {
      local name="$1" attempt status
      shift
      for attempt in 1 2 3; do
        echo "Updating $name (attempt $attempt/3)"
        if "${pkgs.coreutils}/bin/timeout" --kill-after=30s 10m "$@"; then
          echo "Updated $name"
          return 0
        else
          status=$?
          echo "$name update failed (exit $status)" >&2
        fi
        if (( attempt < 3 )); then
          "${pkgs.coreutils}/bin/sleep" "$((attempt * 10))"
        fi
      done
      failures+=("$name")
      return 0
    }

    update_agent amp amp update
    update_agent opencode opencode upgrade
    update_agent codex codex update
    update_agent pi pi update
    update_agent claude claude upgrade

    if (( ''${#failures[@]} )); then
      printf 'Agent updates failed: %s\n' "''${failures[*]}" >&2
      exit 1
    fi
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
        RandomizedDelaySec = "30m";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
