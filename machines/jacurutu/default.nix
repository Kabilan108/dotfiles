{ pkgs, ... }:
{
  imports = [
    ./framework.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "jacurutu";

  services.pipewire.wireplumber.extraConfig."50-mic-volume" = {
    "wireplumber.settings" = {
      "device.routes.default-source-volume" = 0.30;
    };
  };

  environment = {
    systemPackages = with pkgs; [ fprintd ];
  };

  home-manager.users.kabilan = {
    dotfiles.services.mic-volume-enforce.enable = true;

    programs.niri.config = null;
    wallpaper.desktop = "$HOME/dotfiles/wallpapers/shoggoth-001.png";
    wallpaper.lockscreen = "$HOME/dotfiles/wallpapers/war-claude.png";
  };
}
