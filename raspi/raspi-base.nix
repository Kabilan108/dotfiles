{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    # Produces a complete, bootable SD card *image* (firmware + root), not an installer ISO.
    (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
  ];

  nixpkgs.hostPlatform = "aarch64-linux";

  time.timeZone = "America/New_York";

  networking = {
    hostName = "tleilax";
    networkmanager = {
      enable = true;
      # Declarative WiFi. PSK is substituted from an agenix secret via envsubst,
      # so the password never enters the Nix store.
      ensureProfiles = {
        environmentFiles = [ config.age.secrets.wifi-env.path ];
        profiles.windrunner = {
          connection = {
            id = "windrunner";
            type = "wifi";
          };
          wifi = {
            ssid = "windrunner";
            mode = "infrastructure";
          };
          wifi-security = {
            key-mgmt = "wpa-psk";
            psk = "$WIFI_PSK";
          };
          ipv4.method = "auto";
          ipv6.method = "auto";
        };
      };
    };
    # Inbound: closed by default, same posture as sietch/jacurutu.
    # Phase 2 adds egress restriction + Tailscale-only service exposure.
    firewall.enable = true;
  };

  age.secrets.wifi-env.file = ./secrets/wifi-env.age;

  # mDNS so it answers to `tleilax.local` — no router hunting for its IP.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  services.tailscale.enable = true;

  users.users.kabilan = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPN/jpn1y7lmxhrBSmApiVvA+H2YN3AFkczBJbKIGVUe kabilan@jacurutu"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDW1t7U7qDPNYEVWqnxivPK21jkOM5OFwQRmlrQh7XoE kabilan@sietch"
    ];
  };

  # Key-only login with no user password set, so let wheel sudo without one.
  # Phase 2: optionally set an agenix-managed hashedPasswordFile and flip this back.
  security.sudo.wheelNeedsPassword = false;
  users.users.root.hashedPassword = "!";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  environment.systemPackages = with pkgs; [
    git
    htop
    neovim
  ];

  boot.zfs.forceImportRoot = false;

  system.stateVersion = "25.11";
}
