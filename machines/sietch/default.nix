{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/selfhost
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

  systemd.tmpfiles.rules = [
    "d /vault/userdata/tracer-ingest 0755 kabilan users -"
    "d /vault/userdata/tracer-ingest/jacurutu 0755 kabilan users -"
  ];

  home-manager.users.kabilan = {
    dotfiles.services = {
      agent-server.enable = true;
      tracer-digest.enable = true;
      wayvnc.enable = true;
    };

    dotfiles.wallpaper.desktop = "$HOME/dotfiles/wallpapers/uwide/lucy.png";
  };

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [
    22
    5900
  ];

  services = {
    hardware.openrgb.enable = true;
    openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
      settings.KbdInteractiveAuthentication = false;
    };
  };
}
