{ pkgs, ... }:
{
  virtualisation.docker = {
    enable = true;
    daemon.settings.data-root = "/vault/userdata/docker";
  };

  programs = {
    direnv.enable = true; # nix-direnv
    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
    };
    nix-ld.enable = true;
  };

  environment.systemPackages = with pkgs; [
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
