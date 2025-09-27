{
  pkgs,
  inputs,
  ...
}:
{
  config = {
    boot.loader.systemd-boot.enable = true;
    boot.loader.systemd-boot.configurationLimit = 15;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 80;

    networking = {
      nameservers = [
        "1.1.1.1"
        "1.0.0.1"
        "8.8.8.8"
        "8.8.4.4"
      ];
      networkmanager.enable = true;
      networkmanager.plugins = [ pkgs.networkmanager-openvpn ];
      firewall = {
        enable = true;
        interfaces."tailscale0" = {
          allowedTCPPorts = [
            3000
            8000
            5173
          ];
        };
      };
    };

    nix = {
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 2w";
      };
      extraOptions = ''trusted-users = root kabilan'';
      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        # automatically detect duplicated store paths
        auto-optimise-store = true;
      };
    };

    # configure bluetooth & audio
    hardware = {
      bluetooth.enable = true;
      bluetooth.powerOnBoot = true;
    };
    security.rtkit.enable = true;

    services = {
      blueman.enable = true;
      gnome.gnome-keyring.enable = true;
      gvfs.enable = true;
      pulseaudio.enable = false;
      pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };
      tailscale.enable = true;
      udisks2.enable = true;
    };

    programs = {
      appimage.enable = true;
      appimage.binfmt = true;
      nix-ld.enable = true;
      nm-applet.enable = true;
    };

    virtualisation.docker = {
      enable = true;
      daemon.settings.data-root = "/vault/userdata/docker";
    };

    environment.systemPackages = with pkgs; [
      inputs.agenix.packages.${pkgs.system}.default
      inputs.atlas.packages.${pkgs.system}.default
      inputs.capscreen.packages.${pkgs.system}.default
      inputs.diffgpt.packages.${pkgs.system}.default
      inputs.dump.packages.${pkgs.system}.default
      inputs.rollouts.packages.${pkgs.system}.default

      # file system support
      gvfs
      udisks2
      virtiofsd

      # media utils
      ffmpeg-full
      imagemagick
      jmtpfs
      libmtp

      # system utils
      fuse
      git
      htop
      jq
      openssl
      openvpn
      portaudio
      sshfs-fuse
      tailscale
      wget
    ];

    # link /libexec from dreivations to /run/current-system/sw
    environment.pathsToLink = [
      "/libexec"
      "/share/bash-completion"
    ];

    time.timeZone = "America/New_York";
    i18n.defaultLocale = "en_US.UTF-8";
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };

    system.stateVersion = "25.05";
  };
}
