{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.cliproxyapi;
  cliproxyapi = pkgs.callPackage ../../packages/cliproxyapi.nix { };
  configPath = "${config.xdg.configHome}/cliproxyapi/config.yaml";

  claudex = pkgs.writeShellApplication {
    name = "claudex";
    text = ''
      export ANTHROPIC_BASE_URL="http://127.0.0.1:8317"
      export ANTHROPIC_AUTH_TOKEN="claudex-local"
      export ANTHROPIC_MODEL="gpt-5.6-sol"
      export ANTHROPIC_SMALL_FAST_MODEL="gpt-5.6-luna"
      export CLAUDE_CODE_SUBAGENT_MODEL="gpt-5.6-sol"
      export CLAUDE_CODE_ALWAYS_ENABLE_EFFORT=1
      export CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY=3
      export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
      export CLAUDE_CODE_DISABLE_NONSTREAMING_FALLBACK=1
      export ENABLE_TOOL_SEARCH=false

      exec ${config.home.homeDirectory}/.local/bin/claude --model gpt-5.6-sol "$@"
    '';
  };

  codexLogin = pkgs.writeShellApplication {
    name = "cliproxy-codex-login";
    text = ''
      ${lib.getExe cliproxyapi} --codex-login --config ${lib.escapeShellArg configPath} "$@"
      ${pkgs.systemd}/bin/systemctl --user restart cliproxyapi.service
    '';
  };
in
{
  options.dotfiles.services.cliproxyapi.enable = lib.mkEnableOption "CLIProxyAPI for Claude Code";

  config = lib.mkIf cfg.enable {
    home.packages = [
      cliproxyapi
      claudex
      codexLogin
    ];

    xdg.configFile."cliproxyapi/config.yaml".text = ''
      host: "127.0.0.1"
      port: 8317
      auth-dir: "${config.home.homeDirectory}/.cli-proxy-api"
      api-keys:
        - "claudex-local"
      remote-management:
        allow-remote: false
        secret-key: ""
        disable-control-panel: true
      debug: false
      logging-to-file: false
      usage-statistics-enabled: false
    '';

    systemd.user.services.cliproxyapi = {
      Unit = {
        Description = "CLIProxyAPI local model gateway";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        ExecStart = "${lib.getExe cliproxyapi} --config ${configPath}";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
