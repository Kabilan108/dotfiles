{
  config,
  pkgs,
  lib,
  ...
}:

let
  machine = import ./machine.nix;

  currentHostName = machine.hostName;
  isFramework13 = machine.isFramework13;
  enableNvidia = machine.enableNvidia;
  envVars = machine.env;

  rollouts = builtins.getFlake "github:kabilan108/rollouts";
in
{
  imports =
    [
      ./hardware-config.nix
      ./modules/setup-i3.nix
      ./modules/setup-systemd.nix
      ./modules/setup-xbox-controller.nix
    ]
    ++ (lib.optional enableNvidia ./modules/setup-nvidia.nix)
    ++ (lib.optional isFramework13 <nixos-hardware/framework/13-inch/7040-amd>)
    ++ (lib.optional isFramework13 ./modules/setup-framework.nix);

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 80;

  time.timeZone = "America/New_York";

  environment.variables = envVars;

  networking = {
    hostName = currentHostName;
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
          22
          80
          443
          8000
        ];
      };
    };
  };

  users.users.kabilan = {
    isNormalUser = true;
    description = "Tony Kabilan Okeke";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "plugdev"
    ];
    packages = with pkgs; [ ];
    shell = pkgs.bashInteractive;
    openssh.authorizedKeys.keyFiles = [
      ./authorized_keys
    ];
  };

  system.activationScripts.code-agents.text = ''
    ${pkgs.sudo}/bin/sudo -u kabilan ${pkgs.bash}/bin/bash -c '
      export NPM_CONFIG_PREFIX="$HOME/.npm-global"
      export PATH="${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.nodejs_20}/bin:$NPM_CONFIG_PREFIX/bin:$PATH"

      mkdir -p "$NPM_CONFIG_PREFIX/bin"

      for pkg in @anthropic-ai/claude-code opencode-ai@latest ccusage; do
        if ! command -v "$(basename "$pkg")" >/dev/null 2>&1; then
          ${pkgs.nodejs_20}/bin/npm install -g "$pkg" || echo "npm failed to install $pkg"
        fi
      done
    '
  '';

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.extraOptions = ''trusted-users = root kabilan'';
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  virtualisation.docker = {
    enable = true;
    daemon.settings.data-root = "/vault/userdata/docker";
  };

  virtualisation.virtualbox.host.enable = true;
  virtualisation.virtualbox.host.enableExtensionPack = true;
  users.extraGroups.vboxusers.members = [ "kabilan" ];

  nixpkgs.config.allowUnfree = true;

  # configure bluetooth & audio
  hardware = {
    bluetooth.enable = true;
    bluetooth.powerOnBoot = true;
  };
  security.rtkit.enable = true;

  services = {
    blueman.enable = true;
    gnome.gnome-keyring.enable = true;
    hardware.openrgb.enable = true;
    gvfs.enable = true;
    openssh = {
      enable = true;
      settings.PasswordAuthentication = true;
      settings.KbdInteractiveAuthentication = false;
    };
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
    direnv.enable = true; # nix-direnv
    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
    };
    nix-ld.enable = true;
    nm-applet.enable = true;
    steam.enable = true;
  };

  environment.systemPackages =
    with pkgs;
    [
      brave
      baobab
      code-cursor
      discord
      gparted
      inkscape
      libreoffice-fresh
      lxappearance
      nautilus
      obsidian
      openrgb-with-all-plugins
      slack
      spotify
      telegram-desktop
      vlc
      whitesur-gtk-theme
      whitesur-icon-theme
      zotero
      zoom-us

      # mtp support
      libmtp
      jmtpfs
      gvfs
      udisks2

      bashInteractive
      cmake
      fuse
      ffmpeg-full
      gh
      git
      gnumake
      htop
      imagemagick
      jq
      lazydocker
      lazygit
      openssl
      openvpn
      portaudio
      sshfs-fuse
      tailscale
      tree
      tree-sitter
      tmux
      wget
      xclip
      xdotool
      yt-dlp

      direnv
      delta
      fd
      fzf
      ghostty
      kitty.kitten
      neofetch
      pre-commit
      ripgrep
      sd

      bun
      cargo
      clang
      go
      nixd
      nixfmt-rfc-style
      nodejs_20
      python312Full
      pnpm
      uv
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

      (builtins.getFlake "github:kabilan108/capscreen").packages.${builtins.currentSystem}.default
      (builtins.getFlake "github:kabilan108/diffgpt").packages.${builtins.currentSystem}.default
      (builtins.getFlake "github:kabilan108/dump").packages.${builtins.currentSystem}.default

      rollouts.packages.${builtins.currentSystem}.cli
      rollouts.packages.${builtins.currentSystem}.agenix
    ]
    ++ (lib.optional enableNvidia nvtopPackages.full)
    ++ (lib.optional enableNvidia nvidia-container-toolkit)
    ++ (lib.optional enableNvidia cudaPackages.cudatoolkit)
    ++ (lib.optional enableNvidia cudaPackages.cudnn)
    ++ (lib.optional isFramework13 fprintd);

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
  system.stateVersion = "25.05"; # Did you read the comment?
}
