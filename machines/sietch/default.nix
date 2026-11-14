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
  nixpkgs.config.android_sdk.accept_license = true;

  dotfiles.docker.rootlessDevelopment.enable = true;
  dotfiles.mobergTailscale.enable = true;
  services.teamviewer.enable = true;

  # Keep ordinary OpenSSH and key authentication, but require the tailnet for
  # remote administration. Local console access is the recovery path.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];

  # Leave Bluetooth available for deliberate use, but keep its radio off on boot.
  hardware.bluetooth.powerOnBoot = lib.mkForce false;

  # CUDA builds are not covered by cache.nixos.org.
  nix.settings = {
    substituters = [ "https://cache.nixos-cuda.org" ];
    trusted-public-keys = [
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    ];
  };

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
      # pkgsCuda (not blender.override) matches cache.nixos-cuda.org's build.
      pkgsCuda.blender
    ];
  };

  systemd.tmpfiles.rules = [
    "d /vault/userdata/tracer-ingest 0755 kabilan users -"
    "d /vault/userdata/tracer-ingest/jacurutu 0755 kabilan users -"
  ];

  home-manager.users.kabilan = {
    dotfiles.services = {
      flake-update.enable = true;
      russ-playlist-sync.enable = true;
      moberg.devMaintenance.enable = true;
      moberg.devCheckouts.enable = true;
      moberg.eboostReviewerReport.enable = true;
      t3-code = {
        enable = true;
        android.enable = true;
      };
      wayvnc.enable = true;
    };

    # The ingest root is fed by merge-preserving `tracer push` from the fleet,
    # so tag/outcome writes here (e.g. wiki:compiled from tracer-digest)
    # survive re-pushes. Only safe while nothing rsyncs into this root.
    programs.tracer.settings.archive.annotatable_roots = [ "/vault/userdata/tracer-ingest" ];

    dotfiles.wallpaper.lockscreen = "$HOME/dotfiles/wallpapers/uwide/lucy.png";
  };

  # docs/backups.md. Off until the placeholder secrets hold real values.
  age.secrets = lib.mkIf config.dotfiles.backup.enable {
    backup-smb.file = ../../secrets/backup/sietch-smb.age;
    backup-restic.file = ../../secrets/backup/sietch-restic.age;
  };
  dotfiles.backup = {
    enable = true;
    nas = {
      address = "10.0.0.240";
      share = "backup-sietch";
      credentialsFile = config.age.secrets.backup-smb.path;
    };
    passwordFile = config.age.secrets.backup-restic.path;
    statusReceive = [ "jacurutu" ];
    jobs = {
      files.paths = [
        "/vault/notes/coppermind"
        "/vault/userdata/media"
      ];
      services = {
        paths = [
          "/var/lib/vaultwarden"
          "/var/lib/executor"
          "/vault/userdata/hark-server"
        ];
        exclude = [
          "/var/lib/vaultwarden/db.sqlite3*"
          "/var/lib/vaultwarden/icon_cache"
          "/var/lib/executor/data.db*"
          "/vault/userdata/hark-server/hark.sqlite*"
        ];
        sqlite = {
          vaultwarden = {
            database = "/var/lib/vaultwarden/db.sqlite3";
            user = "vaultwarden";
          };
          # The container's distroless nonroot user, with no entry on the host.
          executor = {
            database = "/var/lib/executor/data.db";
            user = "65532";
          };
          hark = {
            database = "/vault/userdata/hark-server/hark.sqlite";
            user = "hark";
          };
        };
      };
    };
  };

  services = {
    hardware.openrgb.enable = true;
    openssh = {
      enable = true;
      openFirewall = false;
      settings.PasswordAuthentication = false;
      settings.KbdInteractiveAuthentication = false;
    };
  };
}
