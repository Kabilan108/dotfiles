{
  displayServer,
  inputs,
  pkgs,
  ...
}:
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
    ../modules/home/appimages.nix
    ../modules/home/pwas.nix
    ../modules/home/wallpaper.nix
    ../modules/home/zen

    inputs.atlas.homeManagerModules.default
    inputs.claude-bar.homeManagerModules.default
    inputs.dictator.homeManagerModules.dictator
    inputs.raindrop.homeManagerModules.default
  ]
  ++ (if displayServer == "x11" then [ ./desktop/x11 ] else [ ./desktop/wayland ]);

  home.username = "kabilan";
  home.homeDirectory = homeDir;
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  programs.yazi = {
    enable = true;
    enableBashIntegration = true;
    plugins = {
      piper = pkgs.yaziPlugins.piper;
    };
    settings = {
      mgr = {
        show_hidden = true;
        show_symlink = true;
      };
      opener = {
        h5 = [
          {
            run = ''viewh5 open "$@"'';
            block = true;
            desc = "View HDF5 file";
          }
        ];
      };
      open = {
        prepend_rules = [
          {
            url = "*.h5";
            use = [ "h5" ];
          }
          {
            url = "*.hdf5";
            use = [ "h5" ];
          }
          {
            url = "*.hdf";
            use = [ "h5" ];
          }
        ];
      };
      plugin = {
        prepend_previewers = [
          {
            url = "*.h5";
            run = ''piper -- viewh5 describe --width "$w" --height "$h" "$1"'';
          }
          {
            url = "*.hdf5";
            run = ''piper -- viewh5 describe --width "$w" --height "$h" "$1"'';
          }
          {
            url = "*.hdf";
            run = ''piper -- viewh5 describe --width "$w" --height "$h" "$1"'';
          }
        ];
      };
    };
  };

  programs.pwas = {
    enable = true;
    apps = [
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

  programs.atlas = {
    enable = true;
    settings = {
      workspace = "moberg-analytics";
      username = "tonykabilanokeke@gmail.com";
      app_password = "\${env:ATLAS_APP_PASSWORD}";
    };
  };

  services.dictator = {
    enable = true;
    displayServer = displayServer; # "x11" | "wayland" | "auto"
    logLevel = "INFO";
    environmentFile = "/run/agenix/secrets/dictator-env";
    settings = {
      api = {
        active_provider = "siren";
        streaming = true;
        timeout = 60;
        providers = {
          siren = {
            endpoint = "https://sietch.sole-pierce.ts.net/siren/v1/audio/transcriptions";
            key = "\${env:SIREN_API_KEY}";
            model = "nvidia/parakeet-tdt-0.6b-v2";
          };
          openai = {
            endpoint = "https://api.openai.com/v1/audio/transcriptions";
            key = "\${env:OPENAI_API_KEY}";
            model = "gpt-4o-transcribe";
          };
        };
      };
      audio = {
        max_duration_min = 20;
      };
    };
  };

  services.claude-bar = {
    enable = true;
    package = inputs.claude-bar.packages.${pkgs.system}.default;
    theme.mode = "dark";
    settings = {
      providers = {
        claude.enabled = true;
        codex.enabled = true;
        merge_icons = false;
      };
      notifications = {
        enabled = true;
        threshold = 0.9;
      };
      popup = {
        display_timeout_ms = 2000;
      };
    };
  };

  programs.raindrop = {
    enable = true;
    package = inputs.raindrop.packages.${pkgs.system}.default;
    settings = {
      token = "\${env:RAINDROP_TOKEN}";
    };
  };

  programs.appimages = {
    enable = true;
    apps = {
      helium = {
        repo = "imputnet/helium-linux";
        pattern = "helium-*.AppImage";
        downloadPattern = "*x86_64.AppImage";
        desktopName = "Helium";
        comment = "Helium Code Editor";
        categories = [
          "Development"
          "IDE"
        ];
      };
      t3code = {
        repo = "pingdotgg/t3code";
        pattern = "T3-Code-*.AppImage";
        downloadPattern = "*x86_64.AppImage";
        desktopName = "T3 Code";
        comment = "T3 Code Editor";
        categories = [
          "Development"
          "TextEditor"
        ];
      };
    };
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
      "x-scheme-handler/chrome" = "google-chrome.desktop";

      "x-scheme-handler/tg" = "org.telegram.desktop.desktop";
      "x-scheme-handler/tonsite" = "org.telegram.desktop.desktop";
    };
  };

  home.packages = with pkgs; [
    # desktop apps
    code-cursor
    discord
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
    zotero

    # media/file handling
    baobab
    bubblewrap
    gparted
    jellyfin-desktop
    nirius
    obs-studio
    rsync
    sox
    unzip
    yt-dlp
    zip

    # build tools
    clang-tools
    cmake
    gnumake

    # dev utils
    inputs.worktrunk.packages.${pkgs.system}.default
    ast-grep
    bat
    cloudflared
    delta
    difftastic
    fastfetch
    fd
    fzf
    gh
    ghostty
    kitty.kitten
    lazygit
    libnotify
    prek
    rclone
    ripgrep
    sd
    tree
    tree-sitter
    tmux
    vhs

    # lsp & formatters
    bash-language-server
    biome
    dockerfile-language-server
    gopls
    just-lsp
    lua-language-server
    nil
    nodePackages.typescript-language-server
    pyright
    ruby
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
    nodejs_24
    python312
    pnpm
    uv
    zig
  ];
}
