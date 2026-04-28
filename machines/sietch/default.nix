{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "sietch";

  programs.steam.enable = true;
  environment = {
    systemPackages = with pkgs; [
      openrgb-with-all-plugins
      prismlauncher
      jdk25
    ];
  };

  home-manager.users.kabilan = {
    dotfiles.services = {
      agent-server.enable = true;
      moberg.eboostReviewerReport.enable = true;
    };

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

  systemd.services.selfhost-update = {
    description = "Pull latest Docker images and restart selfhost services";
    serviceConfig = {
      Type = "oneshot";
      WorkingDirectory = "/home/kabilan/dotfiles/selfhost";
      User = "kabilan";
    };
    path = [
      pkgs.docker
      pkgs.docker-compose
    ];
    script = ''
      source .envrc
      docker-compose pull
      docker-compose up -d
    '';
  };

  systemd.timers.selfhost-update = {
    description = "Monthly Docker image update for selfhost";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "monthly";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };

  users.users.kabilan.openssh.authorizedKeys.keyFiles = [ ./autorized_keys ];
}
