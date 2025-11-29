{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "sietch";

  programs.steam.enable = true;
  environment = {
    systemPackages = with pkgs; [ openrgb-with-all-plugins prismlauncher ];
  };

  home-manager.users.kabilan = {
    wallpaper.desktop = "$HOME/dotfiles/wallpapers/uwide/lucy.png";
  };

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [
    22
    80
    443
  ];

  services = {
    hardware.openrgb.enable = true;
    openssh = {
      enable = true;
      settings.PasswordAuthentication = true;
      settings.KbdInteractiveAuthentication = false;
    };
  };

  users.users.kabilan.openssh.authorizedKeys.keyFiles = [ ./autorized_keys ];
}
