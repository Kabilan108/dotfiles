{ pkgs, ... }:
{
  imports = [
    ./framework.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "jacurutu";

  environment = {
    systemPackages = with pkgs; [ fprintd ];
  };

  home-manager.users.kabilan = {
    programs.niri.config = null;
    xdg.configFile."niri/config.kdl".source = ../../home/desktop/wayland/niri-config.kdl;
    wallpaper.desktop = "$HOME/dotfiles/wallpapers/witcher.png";
    wallpaper.lockscreen = "$HOME/dotfiles/wallpapers/witcher.png";
  };
}
