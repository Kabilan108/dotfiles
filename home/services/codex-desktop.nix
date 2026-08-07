{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.codex-desktop;
  runtimeDir = "/run/user/1000";
  sourceRepo = "${config.home.homeDirectory}/repos/codex-desktop-linux";
  featuresConfig = "${sourceRepo}/linux-features/features.json";
  electronLibPath = lib.makeLibraryPath (
    with pkgs;
    [
      alsa-lib
      at-spi2-core
      cairo
      cups
      dbus
      expat
      gdk-pixbuf
      glib
      gtk3
      libdrm
      libgbm
      libglvnd
      libX11
      libxcb
      libXcomposite
      libxcursor
      libXdamage
      libXext
      libXfixes
      libxi
      libxkbcommon
      libxrandr
      libxscrnsaver
      libxtst
      mesa
      nspr
      nss
      pango
      systemd
      wayland
    ]
  );
  runtimeLibPath = lib.makeLibraryPath (
    with pkgs;
    [
      libxcrypt-legacy
      stdenv.cc.cc.lib
      zlib
    ]
  );

  updateCodexDesktop = pkgs.writeShellScript "update-codex-desktop" ''
    set -euo pipefail

    export PATH="${
      lib.makeBinPath [
        pkgs.bash
        pkgs.cargo
        pkgs.coreutils
        pkgs.curl
        pkgs.gcc
        pkgs.git
        pkgs.gnumake
        pkgs.gnugrep
        pkgs.gnused
        pkgs.nodejs
        pkgs.patchelf
        pkgs.python3
        pkgs.unzip
        pkgs._7zz
      ]
    }:$PATH"

    export CODEX_LINUX_FEATURES_CONFIG="${featuresConfig}"

    updater="$HOME/.local/bin/codex-desktop-update"
    if [ ! -x "$updater" ]; then
      echo "codex-desktop-update is not installed; skipping"
      exit 0
    fi

    exec "$updater" --quiet
  '';
in
{
  options.dotfiles.services.codex-desktop = {
    enable = lib.mkEnableOption "Codex Desktop Linux user-local install helpers";

    updateTimer.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to run the user-local Codex Desktop updater on a timer.";
    };

    ydotool.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to run ydotoold for Computer Use input fallback.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      at-spi2-core
      grim
      ydotool
    ];

    xdg.configFile."codex-desktop-linux/user-local.env" = {
      force = true;
      text = ''
        export LD_LIBRARY_PATH="${electronLibPath}:${runtimeLibPath}:''${LD_LIBRARY_PATH:-}"
      '';
    };

    home.sessionVariables = lib.mkIf cfg.ydotool.enable {
      CODEX_ELECTRON_LD_LIBRARY_PATH = "${electronLibPath}:${runtimeLibPath}";
      YDOTOOL_SOCKET = "${runtimeDir}/.ydotool_socket";
    };

    systemd.user.sessionVariables = lib.mkIf cfg.ydotool.enable {
      CODEX_ELECTRON_LD_LIBRARY_PATH = "${electronLibPath}:${runtimeLibPath}";
      YDOTOOL_SOCKET = "${runtimeDir}/.ydotool_socket";
    };

    systemd.user.services.ydotoold = lib.mkIf cfg.ydotool.enable {
      Unit = {
        Description = "ydotool input daemon";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        Type = "simple";
        ExecStart = "${lib.getExe' pkgs.ydotool "ydotoold"} --socket-path=${runtimeDir}/.ydotool_socket --socket-perm=0600";
        Restart = "on-failure";
        RestartSec = 5;
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };

    systemd.user.services.dotfiles-codex-desktop-update = lib.mkIf cfg.updateTimer.enable {
      Unit = {
        Description = "Update Codex Desktop Linux user-local install";
        After = [ "network-online.target" ];
      };

      Service = {
        Type = "oneshot";
        ExecStart = updateCodexDesktop;
      };
    };

    systemd.user.timers.dotfiles-codex-desktop-update = lib.mkIf cfg.updateTimer.enable {
      Unit.Description = "Periodic Codex Desktop Linux user-local update";
      Timer = {
        OnCalendar = "*-*-* 03:00:00";
        RandomizedDelaySec = "15m";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
