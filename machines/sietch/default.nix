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

  # sietch uses its wired 2.5 GbE link as the LAN data plane. Keep the Wi-Fi
  # hardware available for manual recovery, but disable its radio on every
  # boot and whenever this configuration is activated.
  systemd.services.disable-wifi = {
    description = "Disable the Wi-Fi radio on sietch";
    wantedBy = [ "multi-user.target" ];
    after = [ "NetworkManager.service" ];
    requires = [ "NetworkManager.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.networkmanager}/bin/nmcli radio wifi off";
      RemainAfterExit = true;
    };
  };

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
      moberg.devMaintenance.enable = true;
      t3-code.enable = true;
      wayvnc.enable = true;
    };

    # The ingest root is fed by merge-preserving `tracer push` from the fleet,
    # so tag/outcome writes here (e.g. wiki:compiled from tracer-digest)
    # survive re-pushes. Only safe while nothing rsyncs into this root.
    programs.tracer.settings.archive.annotatable_roots = [ "/vault/userdata/tracer-ingest" ];

    dotfiles.wallpaper.desktop = "$HOME/dotfiles/wallpapers/uwide/lucy.png";
  };

  services = {
    hardware.openrgb.enable = true;
    openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
      settings.KbdInteractiveAuthentication = false;
    };
  };
}
