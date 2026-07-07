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

  colors = config.lib.stylix.colors.withHashtag;
  themeName = "stylix";
in
{
  imports = [
    ./completions
    inputs.try.homeModules.default
  ];

  home.sessionPath = [
    "${homeDir}/.bun/bin"
    "${homeDir}/.local/bin"
    "${homeDir}/.local/share/pnpm/bin"
    "${homeDir}/.opencode/bin"
    "${homeDir}/bin"
    "$GOPATH/bin"
  ];

  home.sessionVariables = rec {
    FZF_DEFAULT_OPTS = "--reverse";

    BUN_INSTALL_CACHE_DIR = "/vault/userdata/cache/bun-install";

    PNPM_HOME = "${homeDir}/.local/share/pnpm";

    UV_CACHE_DIR = "/vault/userdata/cache/uv";
    UV_LINK_MODE = "copy";
    UV_SYSTEM_PYTHON = "0";

    USER_DATA = "/vault/userdata";
    PYREPL_PORT = "5678";

    FASTAI_HOME = "${USER_DATA}/fastai";
    GOPATH = "${USER_DATA}/go";
    HF_HOME = "${USER_DATA}/huggingface";
    HF_DATASETS_CACHE = "$HF_HOME/datasets";
    LLM_USER_PATH = "${USER_DATA}/datasette-llm";
    OLLAMA_MODELS = "${USER_DATA}/ollama/models";
    TORCH_HOME = "${USER_DATA}/torch";
  };

  home.file = {
    ".pi".source = agentLink "pi";
    ".claude".source = agentLink "claude";
    ".codex".source = agentLink "codex";
    ".config/opencode".source = agentLink "opencode";

    ".gitconfig".source = cfgLink ".gitconfig";
    ".ipython/profile_default/ipython_config.py".source = cfgLink "ipython_config.py";
    ".obsidian.vimrc".source = cfgLink ".obsidian.vimrc";
    ".tmux.conf".source = cfgLink ".tmux.conf";
    ".vimrc".source = cfgLink ".vimrc";

    ".config/backup".source = cfgLink "backup";
    ".config/Code/User".source = cfgLink "vscode";
    ".config/Cursor/User".source = cfgLink "vscode";
    ".config/sessionizer".source = cfgLink "sessionizer";
    ".config/uv/uv.toml".source = cfgLink "uv/uv.toml";
    ".config/.bunfig.toml".source = cfgLink "bunfig.toml";
    ".config/pnpm/rc".source = cfgLink "pnpm/rc";
    ".config/nvim".source = cfgLink "nvim";
    ".config/worktrunk".source = cfgLink "worktrunk";
    ".npmrc".source = cfgLink "npm/npmrc";

    "bin".source = config.lib.file.mkOutOfStoreSymlink "${homeDir}/dotfiles/bin";
  };

  home.file.".sessionizer".text = ''
    #!/usr/bin/env bash
    tmux rename-window -t 0 driver 2>/dev/null
  '';

  home.activation.syncAgentSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${homeDir}/dotfiles/bin/sync-agent-skills
  '';

  programs.bash = {
    enable = true;
    initExtra = builtins.readFile ../config/.bashrc;
  };

  # nix-direnv
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };

  programs.atuin = {
    enable = true;
    enableBashIntegration = true;
    settings = {
      style = "compact";
      inline_height = 20;
      keymap_mode = "vim-insert";
      enter_accept = true;
      theme.name = themeName;
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
    settings.git.pagers = [
      { pager = "delta --paging=never"; }
    ];
    settings.gui = {
      authorColors = {
        "*" = colors.base07;
      };
      branchColorPatterns = {
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
}
