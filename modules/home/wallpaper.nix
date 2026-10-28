{
  config,
  lib,
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
}
