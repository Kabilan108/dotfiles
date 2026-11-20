{
  inputs,
  pkgs,
  ...
}:
let
  sessionizer = pkgs.callPackage ../../packages/sessionizer { };
in
{
  imports = [
    inputs.agenix.nixosModules.default
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
    ../../modules/nixos/fleet.nix
    ../../modules/nixos/deploy
    ./alerts.nix
    ./backup.nix
    ./disko.nix
    ./hardware.nix
    ./initrd-unlock.nix
    ./network.nix
    ./services.nix
  ];

  networking.hostName = "tleilax";
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

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
  users.users.kabilan = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.bashInteractive;
  };
  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    openFirewall = false;
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
      home.file."bin/sessionizer".source = "${sessionizer}/bin/sessionizer";
      xdg.configFile."sessionizer/config.json".text = builtins.toJSON {
        search_paths = [ "~" ];
        max_depth = 0;
        remote_hosts = [ ];
      };
      home.stateVersion = "26.11";
    };
  };

  system.stateVersion = "26.11";
}
