{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.cliproxyapi;

  claudex = pkgs.writeShellApplication {
    name = "claudex";
    text = ''
      export ANTHROPIC_BASE_URL="https://cliproxyapi.sole-pierce.ts.net"
      export ANTHROPIC_AUTH_TOKEN="claudex-tailnet"
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
in
{
  options.dotfiles.services.cliproxyapi.enable =
    lib.mkEnableOption "CLIProxyAPI client for Claude Code";

  config = lib.mkIf cfg.enable {
    home.packages = [ claudex ];
  };
}
