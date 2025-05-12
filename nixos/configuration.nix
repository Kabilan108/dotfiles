{ config, pkgs, lib, ... }:

let
  machineCfg = import /etc/nixos/secret/machine-conf.nix;

  currentHostName = machineCfg.hostName;
  enableNvidia = machineCfg.enableNvidia;
  customEnvVars = machineCfg.env;
in
{
  imports = [
    /etc/nixos/hardware-configuration.nix
    ./mod/setup-i3.nix
  ] ++ (lib.optional enableNvidia  ./mod/setup-nvidia.nix);

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 80;

  time.timeZone = "America/New_York";

  environment.variables = customEnvVars;

  networking = {
    hostName = currentHostName;
    networkmanager.enable = true;
    firewall = {
      enable = true;
      interfaces."tailscale0" = {
        allowedTCPPorts = [ 22 80 443 ];
      };
    };
  };

  users.users.kabilan = {
    isNormalUser = true;
    description = "Tony Kabilan Okeke";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    packages = with pkgs; [];
    shell = pkgs.bashInteractive;
    openssh.authorizedKeys.keyFiles = [
      /etc/nixos/secret/authorized_keys
    ];
  };

  virtualisation.docker = {
    enable = true;
  };

  nixpkgs.config.allowUnfree = true;

  # configure bluetooth & audio
  hardware = {
    bluetooth.enable = true;
    bluetooth.powerOnBoot = true;
    pulseaudio.enable = false;
  };
  security.rtkit.enable = true;

  services = {
    blueman.enable = true;
    gnome.gnome-keyring.enable = true;
    openssh = {
      enable = true;
      settings.PasswordAuthentication = true;
      settings.KbdInteractiveAuthentication = false;
    };
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
    tailscale.enable = true;
  };

  programs = {
    direnv.enable = true;  # nix-direnv
    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
    };
  };

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
    htop
    jq
    imagemagick
    openssl
    psmisc
    tailscale
    tree
    tmux
    wget
    xclip

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
    go
    nodejs_20
    zig

    # neovim
    biome
    clang-tools
    dockerfile-language-server-nodejs
    gopls
    lua
    lua-language-server
    luajitPackages.luarocks
    luajitPackages.magick
    nodePackages.typescript-language-server
    pyright
    rust-analyzer
    ruff
  ]
  ++ ((import ./mod/go-tools.nix) { inherit pkgs lib; })
  ++ (lib.optional enableNvidia nvtopPackages.full)
  ++ (lib.optional enableNvidia nvidia-container-toolkit);

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

  # link /libexec from dreivations to /run/current-system/sw
  environment.pathsToLink = [ "/libexec" ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
