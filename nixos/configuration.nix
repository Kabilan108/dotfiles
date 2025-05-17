{ config, pkgs, lib, ... }:

let
  machine = import ./machine.nix;

  currentHostName = machine.hostName;
  enableNvidia = machine.enableNvidia;
  envVars = machine.env;
in
{
  imports = [
    ./hardware-config.nix
    ./modules/setup-i3.nix
  ] ++ (lib.optional enableNvidia  ./modules/setup-nvidia.nix);

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 80;

  time.timeZone = "America/New_York";

  environment.variables = envVars;

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
      ./authorized_keys
    ];
  };
  nix.extraOptions = ''
    trusted-users = root kabilan
  '';

  virtualisation.docker = {
    enable = true;
    daemon.settings.data-root = "/vault/userdata/docker";
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
    openrgb-with-all-plugins
    slack
    spotify
    telegram-desktop
    zotero
    zoom-us

    bashInteractive
    cmake
    fuse
    ffmpeg_6-full
    git
    gnumake
    htop
    imagemagick
    jq
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
    nil
    nodePackages.typescript-language-server
    pyright
    rust-analyzer
    ruff
    stylua
  ]
  ++ ((import ./modules/go-tools.nix) { inherit pkgs lib; })
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
