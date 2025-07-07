{ pkgs, config, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../common/nvidia.nix
    ../../common/xbox-controller.nix
  ];

  networking.hostName = "sietch";

  environment = {
    systemPackages = with pkgs; [
      cudaPackages.cudatoolkit
      cudaPackages.cudnn
      nvtopPackages.full
      nvidia-container-toolkit

      openrgb-with-all-plugins
    ];
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
