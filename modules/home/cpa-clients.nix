{ config, pkgs, ... }:
let
  # CLIProxyAPI on sietch. Its access key is a tailnet-only shared key, not a
  # secret; the tailscale policy is what limits who can reach the service.
  cpaUrl = "https://cliproxyapi.sole-pierce.ts.net";
  cpaKey = "claudex-tailnet";

  # Absolute paths so a wrapper never resolves back to itself through PATH.
  claudeBin = "${config.home.homeDirectory}/.local/bin/claude";
  codexBin = "${config.home.homeDirectory}/.local/bin/codex";
  agyBin = "${config.home.homeDirectory}/.local/bin/agy";

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

  # Antigravity's enterprise gateway mode skips Google sign-in and speaks the
  # Gemini API, which CPA serves on /v1beta. Without a model list agy offers
  # CPA's whole catalog in arbitrary order and starts on its first entry.
  agy-cpa = pkgs.writeShellApplication {
    name = "agy-cpa";
    text = ''
      export AGY_LLM_GATEWAY_URL=${cpaUrl}
      export AGY_LLM_GATEWAY_API_KEY=${cpaKey}
      export AGY_LLM_GATEWAY_MODELS="''${AGY_LLM_GATEWAY_MODELS:-claude-opus-5-5,claude-sonnet-5-5,claude-fable-5-2,claude-haiku-5-5,gpt-6.1-sol,gpt-6.2-sol,gpt-6-astra}"
      exec ${agyBin} "$@"
    '';
  };
in
{
  home.packages = [
    claude-cpa
    codex-cpa
    agy-cpa
  ];
}
