# tleilax: Raspberry Pi 4 for credential services. No coding agents run here.
# Only jacurutu reaches it: Tony's YubiKeys log in, and the laptop's agent
# key can only start a signed deploy or list tmux sessions (deploy-gate).
# Install and recovery: docs/tleilax-install.md.
{
  inputs,
  pkgs,
  ...
}:
let
  sessionizer = pkgs.callPackage ../../packages/sessionizer.nix { };
in
{
  imports = [
    inputs.agenix.nixosModules.default
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
    ../../modules/nixos/fleet.nix
    ../../modules/nixos/deploy
    ./alerts.nix
    ./disko.nix
    ./hardware.nix
    ./initrd-unlock.nix
    ./network.nix
    ./services.nix
  ];

  networking.hostName = "tleilax";
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  # Root's Nix only. kabilan isn't a trusted user, and the only binary cache
  # is cache.nixos.org; nothing sietch signs or serves is trusted.
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      randomizedDelaySec = "2h";
      options = "--delete-older-than 14d";
    };
  };

  users.mutableUsers = false;
  users.users.root.hashedPassword = "!";
  # No password: SSH keys from lib/fleet.nix (modules/nixos/fleet.nix) only.
  users.users.kabilan = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.bashInteractive;
  };
  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    # Reachable over Tailscale only (network.nix).
    openFirewall = false;
    # agenix decrypts with this key; it never leaves the encrypted root.
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "kabilan" ];
      AllowAgentForwarding = "no";
      AllowTcpForwarding = "no";
      AllowStreamLocalForwarding = "no";
      PermitTunnel = "no";
    };
  };

  environment.systemPackages = with pkgs; [
    curl
    fd
    fzf
    git
    htop
    jq
    lsof
    neovim
    ripgrep
    sessionizer
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.kabilan = {
      imports = [ ../../modules/home/shell-base.nix ];
      dotfiles.shellBase.fromCheckout = false;
      # The laptop's picker attaches through "$HOME/bin/sessionizer".
      home.file."bin/sessionizer".source = "${sessionizer}/bin/sessionizer";
      # Sessions only: deploy-gate refuses the laptop agent's requests to
      # preview or create directory sessions, so offer no directories.
      xdg.configFile."sessionizer/config.json".text = builtins.toJSON {
        search_paths = [ ];
        remote_hosts = [ ];
      };
      home.stateVersion = "26.11";
    };
  };

  system.stateVersion = "26.11";
}
