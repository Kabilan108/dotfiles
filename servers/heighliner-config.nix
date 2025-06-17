{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:

let
  appsPath = ./apps;
  appFiles = builtins.attrNames (builtins.readDir appsPath);
  importedApps = map (file: import (appsPath + "/${file}")) appFiles;

  # merge imported app configs into attrset
  appsConfig = lib.foldl lib.recursiveUpdate { } importedApps;

  dotfilesRepo = "https://github.com/kabilan108/dotfiles.git";
  dotfilesPath = "/etc/dotfiles";
in
lib.recursiveUpdate {
  imports = [ (modulesPath + "/virtualisation/digital-ocean-config.nix") ];

  system.stateVersion = "25.05";
  networking.hostName = "heighliner";

  age.secrets.env.file = ./env.age;

  virtualisation.docker.enable = true;
  virtualisation.docker.enableOnBoot = true;
  virtualisation.oci-containers.backend = "docker";

  services.traefik = {
    enable = true;
    dataDir = "/var/lib/traefik";
    staticConfigFile = ./traefik.yml;
    dynamicConfigOptions.providers.docker.exposedbydefault = false;
  };

  users.users.traefik.extraGroups = [ "docker" ];

  systemd.services.traefik.serviceConfig = {
    User = "traefik";
    EnvironmentFile = "${config.age.secrets.env.path}";
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/traefik 0700 traefik traefik -"
    "f /var/lib/traefik/acme.json 0600 traefik traefik -"
    "d /etc/traefik 0755 root root -"
  ];

  environment.etc."traefik/traefik-dynamic.yml" = {
    source = ./traefik-dynamic.yml;
    mode = "0644";
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
      80
      443
    ];
  };

  programs.direnv.enable = true;
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  environment.systemPackages = with pkgs; [
    bash
    cachix
    clang
    curl
    fd
    git
    gnumake
    htop
    jq
    llm
    ripgrep
    tmux
    wget
    xclip
  ];

  system.activationScripts.setupDotfiles = lib.stringAfter [ "users" ] ''
    echo "Setting up dotfiles for root user..."

    # Clone or update dotfiles
    if [ ! -d "${dotfilesPath}" ]; then
      ${pkgs.git}/bin/git clone ${dotfilesRepo} ${dotfilesPath}
    else
      cd ${dotfilesPath}
      ${pkgs.git}/bin/git pull || true
    fi

    # Create root directories
    mkdir -p /root/.config

    # Symlink bash configs
    for file in .bashrc .bash_profile .gitconfig .tmux.conf .vimrc; do
      if [ -f "${dotfilesPath}/conf/$file" ]; then
        ln -sf "${dotfilesPath}/conf/$file" "/root/$file"
      fi
    done

    # Symlink config directories
    if [ -d "${dotfilesPath}/conf/nvim" ]; then
      rm -rf "/root/.config/nvim"
      ln -sf "${dotfilesPath}/conf/nvim" "/root/.config/nvim"
    fi

    # Setup tmux plugins
    if [ ! -d "/root/.tmux/plugins/tpm" ]; then
      mkdir -p /root/.tmux/plugins
      ${pkgs.git}/bin/git clone https://github.com/tmux-plugins/tpm /root/.tmux/plugins/tpm || true
      ${pkgs.git}/bin/git clone -b v2.1.3 https://github.com/catppuccin/tmux.git /root/.tmux/plugins/catppuccin/tmux || true
    fi

    # Symlink bin directory if it exists
    if [ -d "${dotfilesPath}/bin" ]; then
      ln -sf "${dotfilesPath}/bin" /root/bin
    fi

    echo "Dotfiles setup complete for root user!"
  '';

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.substituters = [
    "https://cache.nixos.org"
    "https://kabilan108.cachix.org"
  ];
  nix.settings.trusted-public-keys = [
      "kabilan108.cachix.org-1:g8OqmhpqE1Bz9DjKTV17uQ3yzsfGcDB5fDgGfVC4t/o="
  ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

} appsConfig
