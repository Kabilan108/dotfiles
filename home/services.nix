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

  agentServerStart = pkgs.writeShellScript "agent-server-start" ''
    set -eu
    source "$HOME/.bashenv"

    export PATH="${
      pkgs.lib.makeBinPath [
        pkgs.gcc
        pkgs.gnumake
        pkgs.python3
      ]
    }:$PATH"

    TAILNET_IP="$(${pkgs.tailscale}/bin/tailscale ip -4)"

    ${pkgs.tmux}/bin/tmux new-session -d -s agents \
      "npx t3 serve --host $TAILNET_IP --port 3773 --no-browser"

    ${pkgs.tmux}/bin/tmux split-window -t agents \
      "codex app-server --listen ws://$TAILNET_IP:8390"
  '';

  # moberg crons
  # TODO: remove this after E-BOOST study is complete (07/2026)
  mobergEBOOSTReviewerReport = pkgs.writeShellScript "eboost-reviewer-report" ''
    set -euo pipefail
    cd /vault/work/moberg/dev-server
    source "$HOME/.bashenv"

    ${pkgs.direnv}/bin/direnv exec . \
      eboost-scripts/EBOOST/change-points/scripts/check-eboost-reviewer-progress.sh
  '';
in
{
  systemd.user.services.agent-server = {
    Unit = {
      Description = "Persistent agent servers (Tailscale)";
      After = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStartPre = "-${pkgs.tmux}/bin/tmux kill-session -t agents";
      ExecStart = agentServerStart;
      ExecStop = "${pkgs.tmux}/bin/tmux kill-session -t agents";
    };
    Install.WantedBy = [ "default.target" ];
  };

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

  systemd.user.services.clean-spotify-cache = {
    Unit.Description = "Delete Spotify cache";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.coreutils}/bin/rm -rf %h/.cache/spotify";
    };
  };

  systemd.user.timers.clean-spotify-cache = {
    Unit.Description = "Weekly Spotify cache cleanup";
    Timer = {
      OnCalendar = "Sun 03:00";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # moberg crons
  systemd.user.services.moberg-eboost-reviewer-report = {
    Unit = {
      Description = "Generate EBOOST reviewer progress report";
      After = [ "network-online.target" ];
    };

    Service = {
      Type = "oneshot";
      ExecStart = mobergEBOOSTReviewerReport;
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
}
