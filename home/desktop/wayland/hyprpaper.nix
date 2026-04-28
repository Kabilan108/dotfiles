{ config, ... }:
{
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "on";
      splash = false;
      preload = [ config.dotfiles.wallpaper.desktop ];
      wallpaper = [ ", ${config.dotfiles.wallpaper.desktop}" ];
    };
  };
}
