{ config, pkgs, lib, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      /etc/nixos/hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 80;

  # Enable networking
  networking.hostName = "sietch";
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalisation properties.
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

  # docker
  virtualisation.docker = {
    enable = true;
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.kabilan = {
    isNormalUser = true;
    description = "Tony Kabilan Okeke";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    packages = with pkgs; [];
    shell = pkgs.bashInteractive;
    openssh.authorizedKeys.keyFiles = [
      /etc/nixos/ssh_authorized_keys
    ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # link /libexec from dreivations to /run/current-system/sw
  environment.pathsToLink = [ "/libexec" ];

  # set up X11 and i3wm
  services.displayManager.defaultSession ="none+i3";

  services.xserver = {
    enable = true;

    displayManager = {
      startx.enable = false;
      gdm.enable = true;
    };

    desktopManager.xterm.enable = false;

    windowManager.i3 = {
      enable = true;
      extraPackages = with pkgs; [
        (polybar.override { pulseSupport = true; })
        autotiling
        feh
        dunst
        light
        rofi
        picom
        polybar
        betterlockscreen
        flameshot
        playerctl
        pulseaudio
        pavucontrol
        autorandr
        arandr
        xorg.xrandr
        xorg.xev
      ];
    };

    xkb = {
      layout = "us";
      variant = "";
    };
  };

  # fonts
  fonts.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "FiraMono" ]; })
    fira-mono
  ];
  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      serif = [ "Noto Serif" ];
      sansSerif = [ "Noto Sans" ];
      monospace = ["FiraMono Nerd Font" "Fira Mono" ];
    };
  };

  # configure nvidia drivers
  ## load nvidia driver for Xorg & Wayland
  services.xserver.videoDrivers = ["nvidia"];
  ## enable opengl
  hardware.graphics = {
    enable = true;
  };

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # configure bluetooth support
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  # configure audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    brave
    baobab
    discord
    gparted
    inkscape
    libreoffice-fresh
    nautilus
    obsidian
    slack
    spotify
    telegram-desktop
    zotero

    bashInteractive
    cmake
    fuse
    ffmpeg_6-full
    git
    gnumake
    jq
    imagemagick
    openssl
    psmisc
    tailscale
    tmux
    wget
    xclip

    htop
    nvtopPackages.full

    direnv
    delta
    fd
    fzf
    ghostty
    neofetch
    ripgrep
    sd

    bun
    cargo
    clang
    clang-tools
    go
    lua
    luajitPackages.luarocks
    luajitPackages.magick
    nodejs_20
    zig
  ] ++ (
    (import ./go-tools.nix) { inherit pkgs lib; }
  );

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  # List services that you want to enable:
  services.gnome.gnome-keyring.enable = true;

  # Enable tailscale
  services.tailscale.enable = true;

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
    settings.KbdInteractiveAuthentication = false;
  };

  # Open ports in the firewall.
  networking.firewall = {
    enable = true;
    interfaces."tailscale0" = {
      allowedTCPPorts = [ 22 80 443 ];
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
