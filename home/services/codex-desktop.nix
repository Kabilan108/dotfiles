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
  workingDesktop = "/nix/store/rhmxqq4dgydpb1dlw1ah5g6z3sf1109y-codex-desktop-computer-use-ui-remote-mobile-control-26.527.30818/bin/codex-desktop";
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

  codexDesktopLauncher = pkgs.writeShellScript "codex-desktop-launcher" ''
    set -euo pipefail

    codex_cli_root="$HOME/dotfiles/agents/codex/packages/standalone/releases"
    codex_cli_path="''${CODEX_CLI_PATH:-}"
    if [ -z "$codex_cli_path" ] && [ -d "$codex_cli_root" ]; then
      codex_cli_path="$(
        find "$codex_cli_root" -mindepth 3 -maxdepth 3 -type f -path '*/bin/codex' -perm -0100 \
          | sort -V \
          | tail -n 1
      )"
    fi

    if [ -n "$codex_cli_path" ]; then
      export CODEX_CLI_PATH="$codex_cli_path"
    fi

    export LD_LIBRARY_PATH="${electronLibPath}:${runtimeLibPath}:''${LD_LIBRARY_PATH:-}"

    user_local_desktop="$HOME/.local/opt/codex-desktop-linux/bin/codex-desktop"
    patch_report="$HOME/.local/opt/codex-desktop-linux/codex-app/.codex-linux/patch-report.json"
    if [ -x "$user_local_desktop" ] && { [ ! -f "$patch_report" ] || ! grep -q '"status": "failed-required"' "$patch_report"; }; then
      exec "$user_local_desktop" "$@"
    fi

    if [ -x "${workingDesktop}" ]; then
      exec "${workingDesktop}" "$@"
    fi

    exec "$user_local_desktop" "$@"
  '';

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

    "$updater" --quiet
    install -m 0755 ${codexDesktopLauncher} "$HOME/.local/bin/codex-desktop"
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

    home.file.".local/bin/codex-desktop" = {
      executable = true;
      source = codexDesktopLauncher;
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
        OnBootSec = "10m";
        OnUnitActiveSec = "6h";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
