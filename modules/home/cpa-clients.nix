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
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      export CPA_API_KEY=${cpaKey}
      catalog_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/codex-cpa"
      catalog="$catalog_dir/gpt-catalog.json"
      mkdir -p "$catalog_dir"
      fresh=$(mktemp "$catalog_dir/catalog.XXXXXX")
      if curl -fsS -m 5 -H "Authorization: Bearer $CPA_API_KEY" \
          "${cpaUrl}/v1/models?client_version=$(${codexBin} --version | cut -d' ' -f2)" |
        jq -e '.models |= map(select(.slug | startswith("gpt-"))) | select(.models | length > 0)' >"$fresh"; then
        mv "$fresh" "$catalog"
      else
        rm -f "$fresh"
      fi
      catalog_args=()
      if [[ -s $catalog ]]; then
        catalog_args=(-c "model_catalog_json=\"$catalog\"")
      fi
      exec ${codexBin} -c 'model_provider="cpa"' "''${catalog_args[@]}" "$@"
    '';
  };
in
{
  home.packages = [
    claude-cpa
    codex-cpa
  ];
}
