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

    ".claude/settings.json".source = ./config/claude/settings.json;
    ".claude/commands".source = ./config/claude/commands;

    ".config/nvim".source = ./config/nvim;
    ".config/vscode".source = ./config/vscode;
    ".ipython/profile_default/ipython_config.py".source = ./config/ipython_config.py;

    "bin".source = ./bin;
  };

  programs = {
    direnv.enable = true; # nix-direnv
    home-manager.enable = true;
  };

  programs.bash = {
    enable = true;
    initExtra = builtins.readFile ./config/.bashrc;
  };

  # TODO: move to desktop
  programs.ghostty = {
    enable = true;
    enableBashIntegration = true;
    settings = {
      clipboard-read = "allow";
      clipboard-write = "allow";
      clipboard-trim-trailing-spaces = true;

      adw-toolbar-style = "flat";
      gtk-tabs-location = "bottom";
      gtk-wide-tabs = "false";

      font-family = "FiraMono Nerd Font Mono";

      window-decoration = false;
      window-padding-x = 4;
      window-padding-y = 4;
      window-theme = "ghostty";

      theme = "dotfiles";

      keybind = [
        "alt+0=unbind"
        "alt+1=unbind"
        "alt+2=unbind"
        "alt+3=unbind"
        "alt+4=unbind"
        "alt+5=unbind"
        "alt+6=unbind"
        "alt+7=unbind"
        "alt+8=unbind"
        "alt+9=unbind"
        "performable:alt+s=text:sessionizer\n"
      ];
    };
    themes = {
      dotfiles = with theme; {
        background = "#${palette.base00}";
        foreground = "#${palette.base05}";

        selection-background = "#${palette.base02}";
        selection-foreground = "#${palette.base00}";
        palette = [
          "0=#${palette.base00}"
          "1=#${palette.base08}"
          "2=#${palette.base0B}"
          "3=#${palette.base0A}"
          "4=#${palette.base0D}"
          "5=#${palette.base06}"
          "6=#${palette.base0C}"
          "7=#${palette.base05}"
          "8=#${palette.base03}"
          "9=#${palette.base08}"
          "10=#${palette.base0B}"
          "11=#${palette.base0A}"
          "12=#${palette.base0D}"
          "13=#${palette.base06}"
          "14=#${palette.base0C}"
          "15=#${palette.base07}"
        ];
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
    GTK_THEME = "WhiteSur-Dark";
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

    # themes
    lxappearance
    whitesur-gtk-theme
    whitesur-icon-theme

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
