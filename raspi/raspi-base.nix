{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
let
  userName = "kabilan";
  homeDir = "/home/${userName}";
  linkedBinScripts = [
    {
      name = "pickers";
      path = ./bin/pickers;
    }
    {
      name = "sessionizer";
      path = ./bin/sessionizer;
    }
    {
      name = "tmux-bootstrap-tpm";
      path = ./bin/tmux-bootstrap-tpm;
    }
  ];
  raspiDotfilesBin = pkgs.runCommand "raspi-dotfiles-bin" { } ''
    mkdir -p "$out/bin"
    ${lib.concatMapStringsSep "\n" (script: ''
      install -Dm755 ${script.path} "$out/bin/${script.name}"
    '') linkedBinScripts}
  '';
in
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
      userServices = true;
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

  tleilax.airplayReceiver.enable = true;
  tleilax.jellyfinClient = {
    enable = true;
    autoStart = false;
  };
  tleilax.remote.enable = true;

  users.users.${userName} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    # Mirrors lib/fleet.nix authorizedKeysFor "tleilax" — this flake's root is
    # raspi/, so it cannot import ../lib; keep in sync by hand.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPN/jpn1y7lmxhrBSmApiVvA+H2YN3AFkczBJbKIGVUe kabilan@jacurutu"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDW1t7U7qDPNYEVWqnxivPK21jkOM5OFwQRmlrQh7XoE kabilan@sietch"
      "from=\"100.64.0.0/10\",no-agent-forwarding,no-X11-forwarding,no-port-forwarding ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEzgKJgqnWs1c8Psf5HrCJXTPJ2oHNpyMzjch6/6/HZS agent@sietch"
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
    curl
    fd
    fzf
    gawk
    git
    gnugrep
    htop
    jq
    neovim
    openssh
    procps
    raspiDotfilesBin
    ripgrep
    tmux
  ];

  environment.localBinInPath = true;

  system.activationScripts.raspiUserFiles = {
    deps = [ "users" ];
    text = ''
      ${pkgs.coreutils}/bin/install -d -m 0755 -o ${userName} -g users ${homeDir}/.config

      if [ -L ${homeDir}/.codex ]; then
        ${pkgs.coreutils}/bin/rm ${homeDir}/.codex
      fi

      ${pkgs.coreutils}/bin/install -d -m 0755 -o ${userName} -g users ${homeDir}/.codex
      if [ -L ${homeDir}/.codex/skills ]; then
        ${pkgs.coreutils}/bin/rm ${homeDir}/.codex/skills
      fi
      ${pkgs.coreutils}/bin/install -d -m 0755 -o ${userName} -g users ${homeDir}/.codex/skills

      for target in \
        ${homeDir}/.codex/skills/jellyfin-remote-api \
        ${homeDir}/.tmux.conf \
        ${homeDir}/.config/sessionizer
      do
        if [ -e "$target" ] && [ ! -L "$target" ]; then
          ${pkgs.coreutils}/bin/rm -rf "$target"
        fi
      done

      if [ -L ${homeDir}/.codex/config.toml ]; then
        ${pkgs.coreutils}/bin/rm ${homeDir}/.codex/config.toml
      fi

      ${pkgs.coreutils}/bin/ln -sfnT ${./codex/skills/jellyfin-remote-api} ${homeDir}/.codex/skills/jellyfin-remote-api
      ${pkgs.coreutils}/bin/ln -sfnT ${./codex/config.toml} ${homeDir}/.codex/config.toml
      ${pkgs.coreutils}/bin/ln -sfnT ${./config/.tmux.conf} ${homeDir}/.tmux.conf
      ${pkgs.coreutils}/bin/ln -sfnT ${./config/sessionizer} ${homeDir}/.config/sessionizer
    '';
  };

  boot.zfs.forceImportRoot = false;

  system.stateVersion = "25.11";
}
