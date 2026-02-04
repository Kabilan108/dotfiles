{ config, ... }:
{
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "on";
      splash = false;
      preload = [ config.wallpaper.desktop ];
      wallpaper = [ ", ${config.wallpaper.desktop}" ];
    };
  };
}
