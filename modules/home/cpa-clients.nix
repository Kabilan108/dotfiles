{ config, pkgs, ... }:
let
  # CLIProxyAPI on sietch. Its access key is a tailnet-only shared key, not a
  # secret; the tailscale policy is what limits who can reach the service.
  cpaUrl = "https://cliproxyapi.sole-pierce.ts.net";
  cpaKey = "claudex-tailnet";

  # Absolute paths so a wrapper never resolves back to itself through PATH.
  claudeBin = "${config.home.homeDirectory}/.local/bin/claude";
  codexBin = "${config.home.homeDirectory}/.local/bin/codex";

  claude-cpa = pkgs.writeShellApplication {
    name = "claude-cpa";
    text = ''
      unset ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN
      export ANTHROPIC_BASE_URL=${cpaUrl}
      export ANTHROPIC_AUTH_TOKEN=${cpaKey}
      export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1
      exec ${claudeBin} "$@"
    '';
  };

  # Root-level -c overrides apply to every codex subcommand, including the
  # `app-server` and `exec` modes T3 and scripts use. The provider itself is
  # [model_providers.cpa] in agents/codex/config.toml.
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
