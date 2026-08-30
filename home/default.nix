{
  config,
  displayServer,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  homeDir = "/home/kabilan";
  systemName = pkgs.stdenv.hostPlatform.system;
  notifySend = pkgs.writeShellScriptBin "notify-send" ''
    exec env -u LD_LIBRARY_PATH -u APPDIR -u APPIMAGE ${lib.getExe pkgs.libnotify} "$@"
  '';
  defaultBrowserDesktop = "helium.desktop";
  # Electron apps only build AT-SPI accessibility trees (agent computer use:
  # `acu ui` / `acu act`) when launched with this flag; the session-wide a11y
  # bus flag is not enough. Wraps the binaries and rewrites desktop entries
  # that hardcode the store path.
  withElectronA11y =
    pkg: bins:
    pkgs.symlinkJoin {
      name = "${lib.getName pkg}-a11y";
      paths = [ pkg ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        for bin in ${lib.escapeShellArgs bins}; do
          [ -e "$out/bin/$bin" ] || continue
          wrapProgram "$out/bin/$bin" --add-flags --force-renderer-accessibility
          for entry in "$out"/share/applications/*.desktop; do
            [ -L "$entry" ] || continue
            if grep -q "${pkg}/bin/$bin" "$entry"; then
              target=$(readlink -f "$entry")
              rm "$entry"
              sed "s|${pkg}/bin/$bin|$out/bin/$bin|g" "$target" > "$entry"
            fi
          done
        done
      '';
    };
in
{
  imports = [
    ./services
    ./shell.nix

    ../modules/home/appimages.nix
    ../modules/home/btop.nix
    ../modules/home/fleet.nix
    ../modules/home/fonts.nix
    ../modules/home/ghostty.nix
    ../modules/home/gtk.nix
    ../modules/home/helium.nix
    ../modules/home/pwas.nix
    ../modules/home/stylix.nix
    ../modules/home/wallpaper.nix
    ../modules/home/zen

    inputs.atlas.homeManagerModules.default
    inputs.claude-bar.homeManagerModules.default
    inputs.dictator.homeManagerModules.dictator
    inputs.raindrop.homeManagerModules.default
    inputs.tracer.homeManagerModules.default
  ]
  ++ (if displayServer == "x11" then [ ./desktop/x11 ] else [ ./desktop/wayland ]);

  home.username = "kabilan";
  home.homeDirectory = homeDir;
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  programs.yazi = {
    enable = true;
    enableBashIntegration = true;
    shellWrapperName = "yy";
    plugins = {
      piper = pkgs.yaziPlugins.piper;
    };
    settings = {
      mgr = {
        show_hidden = true;
        show_symlink = true;
      };
      preview.max_width = 2400;
      preview.max_height = 3600;
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
        name = "Messages";
        url = "https://messages.google.com/web";
        icon = "google-messages";
        class = "GoogleMessages";
      }
    ];
  };

  programs.atlas = {
    enable = true;
    settings = {
      workspace = "moberg-analytics";
      username = "tonykabilanokeke@gmail.com";
    };
  };

  services.dictator = {
    enable = true;
    package = inputs.dictator.packages.${systemName}.default;
    displayServer = displayServer; # "x11" | "wayland" | "auto"
    logLevel = "INFO";
    environmentFile = "/run/agenix/secrets/dictator-env";
    settings = {
      api = {
        active_provider = "siren";
        timeout = 60;
        providers = {
          siren = {
            endpoint = "https://siren.sole-pierce.ts.net/v1/audio/transcriptions";
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
      enable_osd = true;
      notifications = "errors_only";
      audio.max_duration_min = 30;
    };
  };

  systemd.user.services.dictator.Unit.X-Restart-Triggers = [
    config.xdg.configFile."dictator/config.json".source
  ];

  services.claude-bar = {
    enable = true;
    package = inputs.claude-bar.packages.${systemName}.default;
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
    package = inputs.raindrop.packages.${systemName}.default;
    settings = {
      token = "\${env:RAINDROP_TOKEN}";
    };
  };

  programs.tracer = {
    enable = true;
    package = inputs.tracer.packages.${systemName}.tracer;
    watch.enable = true;
    settings = {
      archive = {
        root_dir = "~/.local/share/tracer/archive";
        additional_roots = [ "/vault/userdata/tracer-ingest" ];
      };
      ingest.enabled_providers = [
        "claude"
        "codex"
      ];
      ingest.exclude_path_globs = [ "/home/kabilan/experiments/*" ];
    };
  };

  programs.appimages = {
    enable = true;
    apps = {
      t3code = {
        repo = "pingdotgg/t3code";
        pattern = "T3-Code-*.AppImage";
        downloadPattern = "*x86_64.AppImage";
        desktopName = "T3 Code";
        comment = "T3 Code Editor";
        args = [ "--password-store=gnome-libsecret" ];
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
      "image/avif" = "org.gnome.Loupe.desktop";
      "image/bmp" = "org.gnome.Loupe.desktop";
      "image/gif" = "org.gnome.Loupe.desktop";
      "image/heic" = "org.gnome.Loupe.desktop";
      "image/heif" = "org.gnome.Loupe.desktop";
      "image/jpeg" = "org.gnome.Loupe.desktop";
      "image/jxl" = "org.gnome.Loupe.desktop";
      "image/png" = "org.gnome.Loupe.desktop";
      "image/tiff" = "org.gnome.Loupe.desktop";
      "image/webp" = "org.gnome.Loupe.desktop";
      "image/x-eps" = "org.gnome.Loupe.desktop";
      "image/x-ico" = "org.gnome.Loupe.desktop";
      "image/x-portable-bitmap" = "org.gnome.Loupe.desktop";
      "image/x-portable-graymap" = "org.gnome.Loupe.desktop";
      "image/x-portable-pixmap" = "org.gnome.Loupe.desktop";
      "image/x-xbitmap" = "org.gnome.Loupe.desktop";
      "image/x-xpixmap" = "org.gnome.Loupe.desktop";

      "application/pdf" = "org.gnome.Papers.desktop";
      "application/epub+zip" = "org.gnome.Papers.desktop";
      "application/x-mobipocket-ebook" = "org.gnome.Papers.desktop";
      "application/vnd.comicbook+zip" = "org.gnome.Papers.desktop";
      "application/x-cbz" = "org.gnome.Papers.desktop";

      # default browser
      "application/xhtml+xml" = defaultBrowserDesktop;
      "application/x-extension-htm" = defaultBrowserDesktop;
      "application/x-extension-html" = defaultBrowserDesktop;
      "application/x-extension-shtml" = defaultBrowserDesktop;
      "application/x-extension-xht" = defaultBrowserDesktop;
      "application/x-extension-xhtml" = defaultBrowserDesktop;
      "text/html" = defaultBrowserDesktop;
      "x-scheme-handler/http" = defaultBrowserDesktop;
      "x-scheme-handler/https" = defaultBrowserDesktop;
      "x-scheme-handler/mailto" = defaultBrowserDesktop;

      # chromium
      "x-scheme-handler/chrome" = "google-chrome.desktop";

      "x-scheme-handler/tg" = "org.telegram.desktop.desktop";
      "x-scheme-handler/tonsite" = "org.telegram.desktop.desktop";
    };
  };

  home.packages = with pkgs; [
    # desktop apps
    code-cursor
    (withElectronA11y discord [
      "Discord"
      "discord"
    ])
    papers
    loupe
    mpv
    nautilus
    networkmanagerapplet
    (withElectronA11y obsidian [ "obsidian" ])
    pavucontrol
    playerctl
    pulseaudio
    remmina
    seahorse
    signal-desktop
    (withElectronA11y slack [ "slack" ])
    zotero

    # media/file handling
    baobab
    gparted
    gpu-screen-recorder-gtk
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
    ast-grep
    bat
    bubblewrap
    cloudflared
    delta
    difftastic
    fastfetch
    fd
    fzf
    gh
    ghostty
    inputs.herdr.packages.${systemName}.default
    inputs.pagebin.packages.${systemName}.default
    kitty.kitten
    lazygit
    notifySend
    prek
    rclone
    ripgrep
    sd
    tabiew
    tmux
    tree
    tree-sitter
    vhs
    worktrunk

    # lsp & formatters
    bash-language-server
    biome
    dockerfile-language-server
    gopls
    just-lsp
    lua-language-server
    nil
    pyright
    ruff
    rust-analyzer
    shfmt
    stylua
    typescript-language-server
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
    nixfmt
    nodejs_24
    ruby # needed for `try`
    pnpm
    python312
    uv
    zig
  ];

  home.activation.discordModuleLinks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    discordModules="${pkgs.discord}/opt/Discord/modules"
    userModules="$HOME/.config/discord/${pkgs.discord.version}/modules"

    if [ -d "$discordModules" ]; then
      $DRY_RUN_CMD mkdir -p "$userModules"
      for module in "$discordModules"/discord_*; do
        moduleName="$(basename "$module")"
        $DRY_RUN_CMD rm -f "$userModules/$moduleName"
        $DRY_RUN_CMD ln -s "$module" "$userModules/$moduleName"
      done
    fi
  '';
}
