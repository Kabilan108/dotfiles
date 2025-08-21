{ pkgs, inputs, ... }:
let
  dictator = inputs.dictator.packages.${pkgs.system}.default;
in
{
  home.packages = [ dictator ];

  systemd.user.services.dictator = {
    Unit = {
      Description = "Dictator voice typing daemon";
      Documentation = "https://github.com/kabilan108/dictator";
      After = "graphical-session.target";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${dictator}/bin/dictator daemon --log-level INFO";
      Restart = "on-failure";
      RestartSec = "5s";
      Environment = [
        "PATH=${
          pkgs.lib.makeBinPath [
            pkgs.xdotool
            pkgs.xclip
            pkgs.portaudio
          ]
        }"
      ];
      PassEnvironment = [
        "DISPLAY"
        "XAUTHORITY"
        "DBUS_SESSION_BUS_ADDRESS"
      ];
    };
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
          @anthropic-ai/claude-code@latest \
          @openai/codex@latest \
          opencode-ai@latest \
          ccusage@latest
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
      ExecStart = ''
        ${pkgs.uv}/bin/uv tool install -U git+https://github.com/karpathy/rendergit
        ${pkgs.uv}/bin/uv tool install -U llm
        ${pkgs.uv}/bin/uv tool install -U shell_sage
      '';
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
}
