{
  config,
  lib,
  pkgs,
  displayServer,
  ...
}:
{
  options.wallpaper = {
    desktop = lib.mkOption {
      type = lib.types.str;
      description = "Path to desktop wallpaper image";
    };

    lockscreen = lib.mkOption {
      type = lib.types.str;
      default = config.wallpaper.desktop;
      description = "Path to lockscreen wallpaper image (defaults to desktop wallpaper)";
    };
  };

  config = lib.mkMerge [
    # wayland configuration (hyprpaper)
    (lib.mkIf (displayServer == "wayland") {
      services.hyprpaper = {
        enable = true;
        settings = {
          ipc = "on";
          splash = false;
          preload = [ config.wallpaper.desktop ];
          wallpaper = [ ", ${config.wallpaper.desktop}" ];
        };
      };
    })

    # x11 configuration (feh via systemd)
    (lib.mkIf (displayServer == "x11") {
      systemd.user.services.wallpaper = {
        Unit = {
          Description = "Set wallpaper with feh";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.feh}/bin/feh --bg-scale ${config.wallpaper.desktop}";
          RemainAfterExit = true;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    })
  ];
}
