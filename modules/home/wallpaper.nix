{
  config,
  lib,
  pkgs,
  displayServer,
  ...
}:
{
  options.dotfiles.wallpaper = {
    desktop = lib.mkOption {
      type = lib.types.str;
      description = "Path to desktop wallpaper image";
    };

    lockscreen = lib.mkOption {
      type = lib.types.str;
      default = config.dotfiles.wallpaper.desktop;
      description = "Path to lockscreen wallpaper image (defaults to desktop wallpaper)";
    };
  };

  config = lib.mkMerge [
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
          ExecStart = "${pkgs.feh}/bin/feh --bg-scale ${config.dotfiles.wallpaper.desktop}";
          RemainAfterExit = true;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    })
  ];
}
