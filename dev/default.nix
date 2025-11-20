{
  pkgs,
  theme,
  config,
  ...
}:
let
  homeDir = "/home/kabilan";
  confDir = "${homeDir}/dotfiles/config";
  mkLink = name: config.lib.file.mkOutOfStoreSymlink "${confDir}/${name}";
  mkPath = name: ../config/${name};
in
{
  imports = [
    ./systemd-services.nix
    ./bash-completions.nix
  ];

  home.username = "kabilan";
  home.homeDirectory = homeDir;
  home.stateVersion = "25.05";

  home.sessionPath = [
    "$HOME/.bun/bin"
    "$HOME/.local/bin"
    "$HOME/bin"
    "$GOPATH/bin"
  ];

  home.file = {
    ".claude".source = mkLink "claude";
    ".gitconfig".source = mkPath ".gitconfig";
    ".ipython/profile_default/ipython_config.py".source = mkPath "ipython_config.py";
    ".obsidian.vimrc".source = mkPath ".obsidian.vimrc";
    ".tmux.conf".source = mkPath ".tmux.conf";
    ".vimrc".source = mkPath ".vimrc";

    ".config/backup".source = mkLink "backup";
    ".config/Code/User".source = mkLink "vscode";
    ".config/Cursor/User".source = mkLink "vscode";
    ".config/sessionizer".source = mkLink "sessionizer";
    ".config/opencode".source = mkLink "opencode";
    ".config/nvim".source = mkLink "nvim";

    "bin".source = ./bin;
  };

  home.file.".sessionizer".text = ''
    #!/usr/bin/env bash
    tmux rename-window -t 0 nvim 2>/dev/null
    tmux send-keys -t 0 'nvim' C-m
    if ! tmux list-windows | grep -q '^1:'; then
      tmux new-window -t 1 -n shell
    fi
  '';

  programs = {
    direnv.enable = true; # nix-direnv
    home-manager.enable = true;
  };

  programs.bash = {
    enable = true;
    initExtra = builtins.readFile ../config/.bashrc;
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

  home.packages = with pkgs; [
    # desktop apps
    code-cursor
    nautilus
    obsidian
    remmina
    slack
    spotify
    vlc
    vscode-fhs
    windsurf
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
    ast-grep
    bat
    direnv
    delta
    fastfetch
    fd
    fzf
    gh
    ghostty
    kitty.kitten
    lazygit
    pre-commit
    rclone
    ripgrep
    sd
    tree
    tree-sitter
    tmux

    # lsp & formatters
    bash-language-server
    basedpyright
    biome
    dockerfile-language-server-nodejs
    gopls
    lua-language-server
    nil
    nodePackages.typescript-language-server
    rust-analyzer
    ruff
    shfmt
    stylua
    yaml-language-server

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
