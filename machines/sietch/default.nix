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
      codex-remote-control.enable = true;
      t3-code.enable = true;
      wayvnc.enable = true;
    };

    # The ingest root is fed by merge-preserving `tracer push` from the fleet,
    # so tag/outcome writes here (e.g. wiki:compiled from tracer-digest)
    # survive re-pushes. Only safe while nothing rsyncs into this root.
    programs.tracer.settings.archive.annotatable_roots = [ "/vault/userdata/tracer-ingest" ];

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
