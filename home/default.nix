{ pkgs, displayServer, ... }:
let
  homeDir = "/home/kabilan";
in
{
  imports = [
    ./services.nix
    ./shell.nix

    ../modules/home/fonts.nix
    ../modules/home/ghostty.nix
    ../modules/home/gtk.nix
    ../modules/home/pwas.nix
    ../modules/home/wallpaper.nix
    ../modules/home/zen
  ]
  ++ (if displayServer == "x11" then [ ./desktop/x11 ] else [ ./desktop/wayland ]);

  home.username = "kabilan";
  home.homeDirectory = homeDir;
  home.stateVersion = "25.11";

  programs.direnv.enable = true; # nix-direnv
  programs.home-manager.enable = true;

  programs.pwas = {
    enable = true;
    apps = [
      {
        name = "Discord";
        url = "https://discord.com/channels/@me";
        icon = "discord";
        class = "Discord";
      }
      {
        name = "WhatsApp";
        url = "https://web.whatsapp.com";
        icon = "whatsapp";
        class = "WhatsApp";
      }
      {
        name = "Telegram";
        url = "https://web.telegram.org";
        icon = "telegram";
        class = "Telegram";
      }
    ];
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # Images - explicit MIME types (wildcards don't work in XDG)
      "image/avif" = "org.nomacs.ImageLounge.desktop";
      "image/bmp" = "org.nomacs.ImageLounge.desktop";
      "image/gif" = "org.nomacs.ImageLounge.desktop";
      "image/heic" = "org.nomacs.ImageLounge.desktop";
      "image/heif" = "org.nomacs.ImageLounge.desktop";
      "image/jpeg" = "org.nomacs.ImageLounge.desktop";
      "image/jxl" = "org.nomacs.ImageLounge.desktop";
      "image/png" = "org.nomacs.ImageLounge.desktop";
      "image/tiff" = "org.nomacs.ImageLounge.desktop";
      "image/webp" = "org.nomacs.ImageLounge.desktop";
      "image/x-eps" = "org.nomacs.ImageLounge.desktop";
      "image/x-ico" = "org.nomacs.ImageLounge.desktop";
      "image/x-portable-bitmap" = "org.nomacs.ImageLounge.desktop";
      "image/x-portable-graymap" = "org.nomacs.ImageLounge.desktop";
      "image/x-portable-pixmap" = "org.nomacs.ImageLounge.desktop";
      "image/x-xbitmap" = "org.nomacs.ImageLounge.desktop";
      "image/x-xpixmap" = "org.nomacs.ImageLounge.desktop";

      "application/pdf" = "org.gnome.Evince.desktop";
      "application/epub+zip" = "org.gnome.Evince.desktop";
      "application/x-mobipocket-ebook" = "org.gnome.Evince.desktop";
      "application/vnd.comicbook+zip" = "org.gnome.Evince.desktop";
      "application/x-cbz" = "org.gnome.Evince.desktop";

      # default browser
      "application/xhtml+xml" = "zen-beta.desktop";
      "application/x-extension-htm" = "zen-beta.desktop";
      "application/x-extension-html" = "zen-beta.desktop";
      "application/x-extension-shtml" = "zen-beta.desktop";
      "application/x-extension-xht" = "zen-beta.desktop";
      "application/x-extension-xhtml" = "zen-beta.desktop";
      "text/html" = "zen-beta.desktop";
      "x-scheme-handler/http" = "zen-beta.desktop";
      "x-scheme-handler/https" = "zen-beta.desktop";
      "x-scheme-handler/mailto" = "zen-beta.desktop";

      # chromium
      "x-scheme-handler/chrome" = "chromium-browser.desktop";

      "x-scheme-handler/tg" = "org.telegram.desktop.desktop";
      "x-scheme-handler/tonsite" = "org.telegram.desktop.desktop";
    };
  };

  home.packages = with pkgs; [
    # desktop apps
    code-cursor
    evince
    mpv
    nautilus
    networkmanagerapplet
    nomacs
    obsidian
    pavucontrol
    playerctl
    pulseaudio
    remmina
    signal-desktop
    slack
    spotify
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
    libnotify
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
    pyright
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
    python312
    pnpm
    uv
    zig
  ];
}
