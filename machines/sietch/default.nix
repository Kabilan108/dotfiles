{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "sietch";

  environment = {
    systemPackages = [ pkgs.openrgb-with-all-plugins ];
    variables = {
      WALLPAPER = "$HOME/dotfiles/desktop/wallpapers/evangelion-eva-1.png";
    };
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
