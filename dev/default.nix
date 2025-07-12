{
  pkgs,
  lib,
  theme,
  ...
}:
let
  homeDir = "/home/kabilan";
in
{
  imports = [
    ./systemd-services.nix
  ];

  home.username = "kabilan";
  home.homeDirectory = homeDir;
  home.stateVersion = "25.05";

  home.file = {
    ".gitconfig".source = ./config/.gitconfig;
    ".obsidian.vimrc".source = ./config/.obsidian.vimrc;
    ".tmux.conf".source = ./config/.tmux.conf;
    ".vimrc".source = ./config/.vimrc;
    "bin".source = ./bin;

    ".claude".source = ./config/claude;
    ".claude".recursive = true;

    ".config/nvim".source = ./config/nvim;
    ".config/Cursor/User".source = ./config/vscode;
    ".config/Cursor/User".recursive = true;

    ".ipython/profile_default/ipython_config.py".source = ./config/ipython_config.py;
  };

  programs = {
    direnv.enable = true; # nix-direnv
    home-manager.enable = true;
  };

  programs.bash = {
    enable = true;
    initExtra = builtins.readFile ./config/.bashrc;
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
    settings.git.paging.pager = "delta --paging=never";
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

  home.sessionVariables = rec {
    FZF_DEFAULT_OPTS = "--reverse";
    UV_LINK_MODE = "copy";
    UV_SYSTEM_PYTHON = "1";

    CAPSCREEN_OUTPUT_DIR = "$HOME/media/screencasts";
    PYREPL_PORT = "5678";

    USER_DATA = "/vault/userdata";
    FASTAI_HOME = "${USER_DATA}/fastai";
    GOPATH = "${USER_DATA}/go";
    HF_HOME = "${USER_DATA}/huggingface";
    HF_DATASETS_CACHE = "$HF_HOME/datasets";
    LLM_USER_PATH = "${USER_DATA}/datasette-llm";
    OLLAMA_MODELS = "${USER_DATA}/ollama/models";
    TORCH_HOME = "${USER_DATA}/torch";
  };

  # install coding agents
  home.activation.code-agents = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export NPM_CONFIG_PREFIX="$HOME/.npm-global"
    export PATH="${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.nodejs_20}/bin:$NPM_CONFIG_PREFIX/bin:$PATH"

    mkdir -p "$NPM_CONFIG_PREFIX/bin"

    for pkg in @anthropic-ai/claude-code opencode-ai@latest ccusage; do
      if ! command -v "$(basename "$pkg")" >/dev/null 2>&1; then
        ${pkgs.nodejs_20}/bin/npm install -g "$pkg" || echo "npm failed to install $pkg"
      fi
    done
  '';

  home.packages = with pkgs; [
    # desktop apps
    brave
    code-cursor
    discord
    inkscape
    libreoffice-fresh
    nautilus
    obsidian
    slack
    spotify
    telegram-desktop
    vlc
    zoom-us
    zotero

    # media/file handling
    baobab
    gparted
    yt-dlp

    # build tools
    clang-tools
    cmake
    gnumake

    # dev utils
    direnv
    delta
    fd
    fzf
    gh
    ghostty
    kitty.kitten
    lazydocker
    lazygit
    neofetch
    pre-commit
    ripgrep
    sd
    tree
    tree-sitter
    tmux

    # lsp & formatters
    biome
    dockerfile-language-server-nodejs
    gopls
    lua-language-server
    nil
    nodePackages.typescript-language-server
    pyright
    rust-analyzer
    ruff
    stylua

    # languages
    bun
    cargo
    clang
    go
    lua
    luajitPackages.luarocks
    luajitPackages.magick
    nixd
    nixfmt-rfc-style
    nodejs_20
    python312Full
    pnpm
    uv
    zig
  ];
}
