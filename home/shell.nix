{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  homeDir = config.home.homeDirectory;
  confDir = "${homeDir}/dotfiles/config";
  cfgLink = name: config.lib.file.mkOutOfStoreSymlink "${confDir}/${name}";
  agentLink = name: config.lib.file.mkOutOfStoreSymlink "${homeDir}/dotfiles/agents/${name}";

  nixDirenvUnresholved = pkgs.nix-direnv.unresholved.overrideAttrs (_: rec {
    version = "3.1.2";
    src = pkgs.fetchFromGitHub {
      owner = "nix-community";
      repo = "nix-direnv";
      rev = version;
      hash = "sha256-3qT5mSqHi+0cskdoOGPVbuSzkoWtwOHBVXUOL84dAM8=";
    };
    installPhase = ''
      runHook preInstall
      install -m400 -D direnvrc $out/share/nix-direnv/direnvrc
      runHook postInstall
    '';
  });
  nixDirenv = pkgs.nix-direnv.overrideAttrs (_: {
    version = "3.1.2";
    src = nixDirenvUnresholved;
  });

  systemCaEnv = rec {
    SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
    REQUESTS_CA_BUNDLE = SSL_CERT_FILE;
    PIP_CERT = SSL_CERT_FILE;
    DENO_TLS_CA_STORE = "system";
  };

  colors = config.lib.stylix.colors.withHashtag;
  themeName = "stylix";

  syncAntigravityConfig = pkgs.writeShellApplication {
    name = "sync-antigravity-config";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.diffutils
      pkgs.jq
    ];
    text = ''
      repo_root="''${DOTFILES_DIR:-$HOME/dotfiles}"
      cli_dir="$HOME/.gemini/antigravity-cli"
      settings="$cli_dir/settings.json"
      defaults="$repo_root/agents/antigravity-cli/settings.json"

      tmp=""
      cleanup() {
        if [[ -n "$tmp" ]]; then
          rm -f "$tmp"
        fi
      }
      trap cleanup EXIT

      if [[ -r "$defaults" ]]; then
        mkdir -p "$cli_dir"
        if [[ ! -e "$settings" ]] || [[ -f "$settings" && ! -s "$settings" ]]; then
          rm -f "$settings"
          install -m 0600 "$defaults" "$settings"
        elif jq -e 'type == "object"' "$settings" >/dev/null 2>&1; then
          tmp="$(mktemp "$cli_dir/.settings.json.XXXXXX")"
          jq -s '
            def dedup: reduce .[] as $x ([]; if index($x) then . else . + [$x] end);
            .[0] as $cur | .[1] as $def |
            ($cur * $def)
            | if (($cur.trustedWorkspaces | type) == "array") or (($def.trustedWorkspaces | type) == "array") then
                .trustedWorkspaces = ((
                  (if ($cur.trustedWorkspaces | type) == "array" then $cur.trustedWorkspaces else [] end)
                  + (if ($def.trustedWorkspaces | type) == "array" then $def.trustedWorkspaces else [] end)
                ) | dedup)
              else . end
          ' "$settings" "$defaults" > "$tmp"
          chmod 0600 "$tmp"
          if [[ -L "$settings" ]] || ! cmp -s "$tmp" "$settings"; then
            mv -f "$tmp" "$settings"
          else
            rm -f "$tmp"
          fi
          tmp=""
        else
          echo "sync-antigravity-config: skipping merge for non-object JSON at $settings" >&2
        fi
      fi

      ensure_link() {
        local target="$1" link_path="$2"
        if [[ -L "$link_path" && "$(readlink "$link_path")" == "$target" ]]; then
          return 0
        fi
        if [[ ! -e "$link_path" && ! -L "$link_path" ]] || [[ -L "$link_path" ]] || [[ -f "$link_path" && ! -s "$link_path" ]]; then
          mkdir -p "$(dirname "$link_path")"
          ln -sfnT "$target" "$link_path"
        else
          echo "sync-antigravity-config: leaving non-empty file untouched: $link_path" >&2
        fi
      }

      t3_root="$HOME/.t3/userdata/providers/antigravity"
      if [[ -d "$t3_root" ]]; then
        shopt -s nullglob
        for profile in "$t3_root"/*/; do
          profile="''${profile%/}"
          if [[ -e "$HOME/.gemini/config/AGENTS.md" ]]; then
            ensure_link "$HOME/.gemini/config/AGENTS.md" "$profile/config/AGENTS.md"
          fi
          if [[ -e "$HOME/.gemini/config/mcp_config.json" ]]; then
            ensure_link "$HOME/.gemini/config/mcp_config.json" "$profile/config/mcp_config.json"
          fi
          if [[ -d "$profile/antigravity-acp" && -d "$cli_dir" ]]; then
            ensure_link "$cli_dir/mcp_oauth_tokens.json" "$profile/antigravity-acp/mcp_oauth_tokens.json"
          fi
        done
      fi
    '';
  };
in
{
  imports = [
    ../modules/home/shell-base.nix
    inputs.try.homeModules.default
  ];

  home.sessionPath = [
    "${homeDir}/.bun/bin"
    "${homeDir}/.cargo/bin"
    "${homeDir}/.local/bin"
    "${homeDir}/.local/share/pnpm"
    "${homeDir}/.local/share/pnpm/bin"
    "${homeDir}/.opencode/bin"
    "${homeDir}/bin"
    "$GOPATH/bin"
  ];

  systemd.user.sessionVariables = systemCaEnv;

  home.sessionVariables = systemCaEnv // rec {
    FZF_DEFAULT_OPTS = "--reverse";

    BLEND_CACHE_DIR = "/vault/userdata/cache/blender";
    BUN_INSTALL_CACHE_DIR = "/vault/userdata/cache/bun-install";

    GRADLE_USER_HOME = "/vault/userdata/cache/gradle";
    NPM_CONFIG_CACHE = "/vault/userdata/cache/npm";
    PNPM_HOME = "${homeDir}/.local/share/pnpm";

    UV_CACHE_DIR = "/vault/userdata/cache/uv";
    UV_LINK_MODE = "copy";
    UV_MALWARE_CHECK = "1";
    UV_SYSTEM_PYTHON = "0";

    NIX_SSHOPTS = "-o RequestTTY=no";

    USER_DATA = "/vault/userdata";
    PYREPL_PORT = "5678";

    FASTAI_HOME = "${USER_DATA}/fastai";
    GOPATH = "${USER_DATA}/go";
    HF_HOME = "${USER_DATA}/huggingface";
    HF_TOKEN_PATH = "$HOME/.config/huggingface/token";
    HF_DATASETS_CACHE = "$HF_HOME/datasets";
    OLLAMA_MODELS = "${USER_DATA}/ollama/models";
    TORCH_HOME = "${USER_DATA}/torch";
  };

  home.file = {
    ".pi".source = agentLink "pi";
    ".claude".source = agentLink "claude";
    ".codex".source = agentLink "codex";
    ".config/opencode".source = agentLink "opencode";
    ".gemini/config".source = agentLink "antigravity";

    ".gitconfig".source = cfgLink ".gitconfig";
    ".ipython/profile_default/ipython_config.py".source = cfgLink "ipython_config.py";

    ".config/Code/User".source = cfgLink "vscode";
    ".config/sessionizer".source = cfgLink "sessionizer";
    ".config/uv/uv.toml".source = cfgLink "uv/uv.toml";
    ".config/.bunfig.toml".source = cfgLink "bunfig.toml";
    ".config/pnpm/config.yaml".source = cfgLink "pnpm/config.yaml";
    ".config/moxide".source = cfgLink "moxide";
    ".config/nvim".source = cfgLink "nvim";
    ".npmrc".source = cfgLink "npm/npmrc";

    "bin".source = config.lib.file.mkOutOfStoreSymlink "${homeDir}/dotfiles/bin";
    "media".source = config.lib.file.mkOutOfStoreSymlink "/vault/userdata/media";
  };

  home.packages = [ (pkgs.callPackage ../packages/sessionizer { }) ];

  home.file.".sessionizer".text = ''
    #!/usr/bin/env bash
    tmux rename-window -t 0 driver 2>/dev/null
  '';

  home.activation.syncAgentSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    PATH="${pkgs.jq}/bin:$PATH" $DRY_RUN_CMD ${homeDir}/dotfiles/bin/sync-agent-skills
  '';

  home.activation.syncAntigravityConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    $DRY_RUN_CMD ${lib.getExe syncAntigravityConfig}
  '';

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv = {
      enable = true;
      package = nixDirenv;
    };
  };

  programs.atuin = {
    enable = true;
    enableBashIntegration = true;
    daemon.enable = true;
    settings = {
      style = "compact";
      inline_height = 20;
      keymap_mode = "vim-insert";
      enter_accept = true;
      theme.name = themeName;
      threads.capture = true;
      daemon.autostart = false;
      teams.enabled = false;
    };
    themes = {
      "${themeName}" = {
        theme.name = themeName;
        colors = {
          AlertInfo = colors.base0B;
          AlertWarn = colors.base09;
          AlertError = colors.base08;
          Annotation = colors.base0E;
          Base = colors.base05;
          Guidance = colors.base04;
          Important = colors.base08;
          Title = colors.base0E;
        };
      };
    };
  };

  programs.lazydocker = {
    enable = true;
    settings.gui.theme = {
      activeBorderColor = [
        colors.base0A
        "bold"
      ];
      inactiveBorderColor = [ colors.base03 ];
      selectedLineBgColor = [ colors.base02 ];
      optionsTextColor = [ colors.base0D ];
    };
  };

  stylix.targets.lazygit.enable = true;

  programs.lazygit = {
    enable = true;
    settings.git.diffRenderers = [
      { command = "delta --paging=never"; }
    ];
    settings.gui = {
      theme.authorColors = {
        "*" = colors.base07;
      };
      theme.branchColorPatterns = {
        "^main$" = colors.base0C;
        "^master$" = colors.base0C;
        "^feat[ure]?/" = colors.base0D;
        "^bugfix/" = colors.base08;
        "^fix/" = colors.base08;
      };
      nerdFontsVersion = "3";
    };
  };

  programs.neovim = {
    enable = true;
    extraPackages = [ pkgs.inotify-tools ];
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    sideloadInitLua = true;
    withPython3 = false;
    withRuby = false;
  };

  programs.try = {
    enable = true;
    path = "~/experiments";
  };

  xdg.configFile."try-session.env".text = ''
    TRY_BIN=${lib.escapeShellArg (lib.getExe' config.programs.try.package "try")}
    TRY_PATH=${lib.escapeShellArg config.programs.try.path}
  '';
}
