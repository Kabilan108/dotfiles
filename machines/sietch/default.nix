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

  boot.initrd.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
    "nvidia_drm"
  ];
  boot.loader.systemd-boot.configurationLimit = lib.mkForce 8;

  dotfiles.docker.rootlessDevelopment.enable = true;
  dotfiles.mobergTailscale.enable = true;
  services.teamviewer.enable = true;

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];

  services.tailscale.extraSetFlags = lib.mkForce [ "--operator=" ];

  hardware.bluetooth.powerOnBoot = lib.mkForce false;

  nix.settings = {
    substituters = [ "https://cache.nixos-cuda.org" ];
    trusted-public-keys = [
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    ];
  };

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
  programs._1password.enable = true;
  environment = {
    systemPackages = with pkgs; [
      openrgb-with-all-plugins
      prismlauncher
      jdk25
      pkgsCuda.blender
    ];
  };

  systemd.tmpfiles.rules = [
    "d /vault/userdata/tracer-ingest 0755 kabilan users -"
    "d /vault/userdata/tracer-ingest/jacurutu 0755 kabilan users -"
    "z /var/lib/vaultwarden 0700 root root -"
    "d /vault/userdata/vms 0755 kabilan users -"
  ];

  home-manager.users.kabilan = {
    systemd.user.slices.vms = {
      Unit.Description = "VMs started by agents";
      Slice = {
        CPUQuota = "1600%";
        MemoryMax = "28G";
        MemorySwapMax = "0";
      };
    };

    dotfiles.services = {
      flake-update.enable = true;
      jetkvm-update-check.enable = true;
      moberg.devMaintenance.enable = true;
      moberg.devCheckouts.enable = true;
      moberg.eboostReviewerReport.enable = true;
      t3-code = {
        enable = true;
        android.enable = true;
      };
      wayvnc.enable = true;
    };

    programs.tracer.settings.archive.annotatable_roots = [ "/vault/userdata/tracer-ingest" ];

    dotfiles.wallpaper.lockscreen = "$HOME/dotfiles/wallpapers/uwide/lucy.png";
  };

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
    timer = {
      OnCalendar = "*-*-* 09:00:00 UTC";
      RandomizedDelaySec = "30m";
      Persistent = "true";
    };
    statusReceive = [ "jacurutu" ];
    jobs = {
      files.paths = [
        "/vault/notes/coppermind"
        "/vault/userdata/media"
      ];
      services = {
        paths = [ "/vault/userdata/hark-server" ];
        exclude = [ "/vault/userdata/hark-server/hark.sqlite*" ];
        sqlite.hark = {
          database = "/vault/userdata/hark-server/hark.sqlite";
          user = "hark";
        };
      };
    };
  };

  services = {
    hardware.openrgb.enable = true;
    resolved.enable = true;
    openssh = {
      enable = true;
      openFirewall = false;
      settings.PasswordAuthentication = false;
      settings.KbdInteractiveAuthentication = false;
    };
  };
}
