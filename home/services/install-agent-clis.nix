{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.install-agent-clis;
in
{
  options.dotfiles.services.install-agent-clis.enable = lib.mkEnableOption "Agent CLI refresh";

  config = lib.mkIf cfg.enable {
    systemd.user.services.install-agent-clis = {
      Unit = {
        Description = "Install/Update Agent CLIs";
        After = "network-online.target";
      };
      Service = {
        Type = "oneshot";
        ExecStart = ''
          ${pkgs.bun}/bin/bun install -g \
            @openai/codex@latest \
            opencode-ai@latest \
            @mariozechner/pi-coding-agent
        '';
      };
      Install.WantedBy = [ "default.target" ];
    };

    systemd.user.timers.install-agent-clis = {
      Unit.Description = "Daily refresh of Agent CLIs";
      Timer = {
        OnBootSec = "5m";
        OnUnitActiveSec = "24h";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
