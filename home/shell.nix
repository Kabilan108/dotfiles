{
  inputs,
  config,
  theme,
  pkgs,
  ...
}:
let
  homeDir = "/home/kabilan";
  confDir = "${homeDir}/dotfiles/config";
  cfgLink = name: config.lib.file.mkOutOfStoreSymlink "${confDir}/${name}";
  agentLink = name: config.lib.file.mkOutOfStoreSymlink "${homeDir}/dotfiles/agents/${name}";
  mkPath = name: ../config/${name};

  themeName = theme.name;
  palette = theme.palette;
in
{
  imports = [
    ./completions
    inputs.try.homeModules.default
  ];

  home.sessionPath = [
    "$HOME/.bun/bin"
    "$HOME/.local/bin"
    "$HOME/.npm-global/bin"
    "$HOME/bin"
    "$GOPATH/bin"
  ];

  home.sessionVariables = rec {
    FZF_DEFAULT_OPTS = "--reverse";

    BUN_INSTALL_CACHE_DIR = "/vault/userdata/cache/bun-install";

    UV_CACHE_DIR = "/vault/userdata/cache/uv";
    UV_LINK_MODE = "copy";
    UV_SYSTEM_PYTHON = "0";

    PYREPL_PORT = "5678";
    AGENT_BROWSER_EXECUTABLE_PATH = "${pkgs.google-chrome}/bin/google-chrome-stable";

    USER_DATA = "/vault/userdata";
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

    ".gitconfig".source = mkPath ".gitconfig";
    ".ipython/profile_default/ipython_config.py".source = mkPath "ipython_config.py";
    ".obsidian.vimrc".source = mkPath ".obsidian.vimrc";
    ".tmux.conf".source = mkPath ".tmux.conf";
    ".vimrc".source = mkPath ".vimrc";

    ".config/backup".source = cfgLink "backup";
    ".config/Code/User".source = cfgLink "vscode";
    ".config/Cursor/User".source = cfgLink "vscode";
    ".config/sessionizer".source = cfgLink "sessionizer";
    ".config/uv/uv.toml".source = cfgLink "uv/uv.toml";
    ".config/.bunfig.toml".source = cfgLink "bunfig.toml";
    ".config/nvim".source = cfgLink "nvim";
    ".config/worktrunk".source = cfgLink "worktrunk";
    ".npmrc".source = cfgLink "npm/npmrc";

    "bin".source = config.lib.file.mkOutOfStoreSymlink "${homeDir}/dotfiles/bin";
  };

  home.file.".sessionizer".text = ''
    #!/usr/bin/env bash
    tmux rename-window -t 0 driver 2>/dev/null
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
          AlertInfo = "#${palette.base0B}";
          AlertWarn = "#${palette.base09}";
          AlertError = "#${palette.base08}";
          Annotation = "#${palette.base0E}";
          Base = "#${palette.base05}";
          Guidance = "#${palette.base04}";
          Important = "#${palette.base08}";
          Title = "#${palette.base0E}";
        };
      };
    };
  };

  programs.lazydocker = {
    enable = true;
    settings.gui.theme = with theme.palette; {
      activeBorderColor = [
        "#${base0A}"
        "bold"
      ];
      inactiveBorderColor = [ "#${base03}" ];
      selectedLineBgColor = [ "#${base02}" ];
      optionsTextColor = [ "#${base0D}" ];
    };
  };

  programs.lazygit = {
    enable = true;
    settings.git.pagers = [
      { pager = "delta --paging=never"; }
    ];
    settings.gui = with theme.palette; {
      authorColors = {
        "*" = "#${base07}";
      };
      branchColorPatterns = {
        "^main$" = "#94e2d5";
        "^master$" = "#94e2d5";
        "^feat[ure]?/" = "#74c7ec";
        "^bugfix/" = "#eba0ac";
        "^fix/" = "#eba0ac";
      };
      nerdFontsVersion = "3";
      theme = {
        activeBorderColor = [
          "#${base0A}"
          "bold"
        ];
        cherryPickedCommitBgColor = [ "#${base03}" ];
        cherryPickedCommitFgColor = [ "#${base0A}" ];
        defaultFgColor = [ "#${base05}" ];
        inactiveBorderColor = [ "#${base03}" ];
        optionsTextColor = [ "#${base0D}" ];
        searchingActiveBorderColor = [ "#${base0A}" ];
        selectedLineBgColor = [ "#${base02}" ];
        unstagedChangesColor = [ "#${base08}" ];
      };
    };
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  programs.try = {
    enable = true;
    path = "~/experiments";
  };
}
