{ config, pkgs, ... }:
let
  cpaUrl = "https://cliproxyapi.sole-pierce.ts.net";
  cpaKey = "claudex-tailnet";

  claudeBin = "${config.home.homeDirectory}/.local/bin/claude";
  codexBin = "${config.home.homeDirectory}/.local/bin/codex";

  claude-cpa = pkgs.writeShellApplication {
    name = "claude-cpa";
    text = ''
      unset ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN
      export ANTHROPIC_BASE_URL=${cpaUrl}
      export ANTHROPIC_AUTH_TOKEN=${cpaKey}
      exec ${claudeBin} "$@"
    '';
  };

  codex-cpa = pkgs.writeShellApplication {
    name = "codex-cpa";
    text = ''
      export CPA_API_KEY=${cpaKey}
      exec ${codexBin} -c 'model_provider="cpa"' "$@"
    '';
  };
in
{
  home.packages = [
    claude-cpa
    codex-cpa
  ];
}
