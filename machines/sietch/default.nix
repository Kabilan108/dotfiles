{ config, lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "sietch";

  age.secrets.wayvnc-config = {
    file = ../../secrets/wayvnc-config.age;
    owner = "kabilan";
    mode = "400";
  };

  programs.steam.enable = true;
  environment = {
    systemPackages = with pkgs; [ openrgb-with-all-plugins prismlauncher ];
  };

  home-manager.users.kabilan = {
    wallpaper.desktop = "$HOME/dotfiles/wallpapers/uwide/lucy.png";

    services.wayvnc = {
      enable = true;
      autoStart = true;
    };

    # mkForce overrides the module's generated config with our agenix secret
    xdg.configFile."wayvnc/config".source =
      lib.mkForce config.age.secrets.wayvnc-config.path;
  };

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [
    22
    80
    443
    5900
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
