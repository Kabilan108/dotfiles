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
    wallpaper.desktop = "$HOME/dotfiles/wallpapers/witcher.png";
    wallpaper.lockscreen = "$HOME/dotfiles/wallpapers/witcher.png";
  };
}
