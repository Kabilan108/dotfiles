{
  pkgs,
  ...
}:
let
  backupJob = pkgs.writeShellScript "backup-weekly-job" ''
    set -eu
    "$HOME/bin/backup" push
    "$HOME/bin/backup" janitor
  '';
in
{
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
          @sourcegraph/amp
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

  systemd.user.services.install-uv-tools = {
    Unit = {
      Description = "Install/Update uv tools";
      After = "network-online.target";
    };
    Service = {
      Type = "oneshot";
      ExecStart = [
        "${pkgs.uv}/bin/uv tool install -U git+https://github.com/karpathy/rendergit"
        "${pkgs.uv}/bin/uv tool install -U --with llm-cmd --with llm-openrouter --with llm-tmux-fragments llm"
      ];
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.timers.install-uv-tools = {
    Unit.Description = "Daily refresh of uv tools";
    Timer = {
      OnBootSec = "5m";
      OnUnitActiveSec = "24h";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  systemd.user.services.backup-weekly = {
    Unit = {
      Description = "Weekly backup push and janitor";
      After = "network-online.target";
    };
    Service = {
      Type = "oneshot";
      ExecStart = backupJob;
      Environment = [
        "PATH=%h/bin:${
          pkgs.lib.makeBinPath [
            pkgs.uv
            pkgs.rclone
          ]
        }"
      ];
    };
  };

  systemd.user.timers.backup-weekly = {
    Unit.Description = "Weekly backup run";
    Timer = {
      OnCalendar = "Mon 01:00";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
