{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.tleilax.jellyfinClient;

  jellyfinKiosk = pkgs.writeShellScript "jellyfin-kiosk" ''
    log_dir="''${XDG_STATE_HOME:-$HOME/.local/state}"
    mkdir -p "$log_dir"
    exec >> "$log_dir/jellyfin-kiosk.log" 2>&1

    echo "=== jellyfin kiosk start $(date --iso-8601=seconds) ==="
    export LIBSEAT_BACKEND=logind
    export QT_QPA_PLATFORM=wayland
    export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
    export QTWEBENGINE_CHROMIUM_FLAGS="--ozone-platform=wayland --enable-features=UseOzonePlatform"

    exec ${lib.getExe pkgs.cage} -s -- ${lib.getExe pkgs.jellyfin-media-player}
  '';
in
{
  options.tleilax.jellyfinClient = {
    enable = lib.mkEnableOption "Jellyfin Desktop as a fullscreen HDMI client";

    user = lib.mkOption {
      type = lib.types.str;
      default = "kabilan";
      description = "User that owns the Jellyfin Desktop kiosk session.";
    };

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start Jellyfin Desktop on tty1 through greetd.";
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.graphics.enable = true;

    services.dbus.enable = true;
    systemd.user.services.dbus-broker.restartIfChanged = false;

    boot.kernelParams = [ "video=HDMI-A-1:1920x1080@60" ];

    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    services.greetd = lib.mkIf cfg.autoStart {
      enable = true;
      restart = true;
      settings = {
        initial_session = {
          command = jellyfinKiosk;
          user = cfg.user;
        };
        default_session = {
          command = jellyfinKiosk;
          user = cfg.user;
        };
      };
    };

    users.users.${cfg.user}.extraGroups = [
      "audio"
      "input"
      "render"
      "video"
    ];

    environment.systemPackages = with pkgs; [
      cage
      jellyfin-media-player
      libva-utils
      vulkan-tools
    ];
  };
}
