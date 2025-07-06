{ pkgs, ... }:
{
  imports = [
    ./framework.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "jacurutu";

  environment = {
    systemPackages = with pkgs; [ fprintd ];
    variables = {
      WALLPAPER = "$HOME/media/wallpapers/japan-alley.png";
    };
  };
}
