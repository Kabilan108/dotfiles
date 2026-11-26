{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:
let
  home = config.users.users.kabilan.home;
  hostName = config.networking.hostName;
  isSietch = hostName == "sietch";
  personalKeystore = "${home}/.android/personal.keystore";
  userTokensPath = config.age.secrets."secrets/nix-access-tokens-user.age".path;
  mobergVpnCertFile =
    if isSietch then ./secrets/moberg/vpn/sietch-cert.age else ./secrets/moberg/vpn/cert.age;
  mobergVpnKeyFile =
    if isSietch then ./secrets/moberg/vpn/sietch-key.age else ./secrets/moberg/vpn/key.age;
  opServiceAccountFile =
    if isSietch then ./secrets/op/sietch-agents.age else ./secrets/op/jacurutu-agents.age;
  isHarkHost = builtins.elem hostName [
    "sietch"
    "jacurutu"
  ];
  harkConfigFile =
    if hostName == "sietch" then
      ./secrets/hark/sietch-config.json.age
    else
      ./secrets/hark/jacurutu-config.json.age;
in
{
  users.users.kabilan = {
    isNormalUser = true;
    description = "Tony Kabilan Okeke";
    extraGroups = [
      "networkmanager"
      "wheel"
      "plugdev"
      "input"
    ]
    ++ lib.optionals config.dotfiles.docker.rootlessDevelopment.allowRootfulUserAccess [ "docker" ];
    shell = pkgs.bashInteractive;
    linger = true;
  };

  environment.systemPackages = [ pkgs.bashInteractive ];

  environment.sessionVariables = lib.mkIf isSietch {
    ANDROID_PERSONAL_KEYSTORE = personalKeystore;
  };

  age = {
    identityPaths = [ "${home}/.ssh/id_ed25519" ];
    secretsDir = "/run/agenix";
    secrets."secrets/agent-browser-encryption-key.age" = {
      file = ./secrets/agent-browser-encryption-key.age;
      path = "${home}/.agent-browser/.encryption-key";
      mode = "0600";
      owner = "kabilan";
      group = "users";
    };
    secrets."secrets/pagebin/env.age" = {
      file = ./secrets/pagebin/env.age;
      path = "${home}/.config/pagebin/env";
      mode = "0600";
      owner = "kabilan";
      group = "users";
    };
    secrets."secrets/rclone.conf" = {
      file = ./secrets/rclone.conf;
      path = "${home}/.config/rclone/rclone.conf";
      mode = "0600";
      owner = "kabilan";
      group = "users";
    };
    secrets."secrets/executor/meeting-minutes.age" =
      lib.mkIf (builtins.pathExists ./secrets/executor/meeting-minutes.age)
        {
          file = ./secrets/executor/meeting-minutes.age;
          path = "${home}/.config/meeting-minutes/executor-env";
          mode = "0600";
          owner = "kabilan";
          group = "users";
        };
    secrets."secrets/android/personal-keystore.age" = lib.mkIf isSietch {
      file = ./secrets/android/personal-keystore.age;
      path = personalKeystore;
      mode = "0600";
      owner = "kabilan";
      group = "users";
    };
    secrets."secrets/dictator-env" = {
      file = ./secrets/dictator-env;
      mode = "0600";
      owner = "kabilan";
      group = "users";
    };
    secrets."secrets/gog-oauth-client" = {
      file = ./secrets/gogcli/credentials-json.age;
      mode = "0600";
      owner = "kabilan";
      group = "users";
    };
    secrets."secrets/gog-keyring-env" = {
      file = ./secrets/gogcli/keyring-env.age;
      mode = "0600";
      owner = "kabilan";
      group = "users";
    };

    secrets."secrets/gh-token" =
      lib.mkIf (isSietch && builtins.pathExists ./secrets/gh/sietch-token.age)
        {
          file = ./secrets/gh/sietch-token.age;
          mode = "0400";
          owner = "kabilan";
          group = "users";
        };

    secrets."secrets/op/agents.age" = {
      file = opServiceAccountFile;
      path = "${home}/.config/op-agents/env";
      mode = "0400";
      owner = "kabilan";
      group = "users";
    };

    secrets."secrets/moberg/credentials.env.age" = {
      file = ./secrets/moberg/credentials.env.age;
      path = "${home}/.config/moberg/credentials.env";
      mode = "0600";
      owner = "kabilan";
      group = "users";
    };
    secrets."secrets/moberg/secrets.env.age" = {
      file = ./secrets/moberg/secrets.env.age;
      path = "${home}/.config/moberg/secrets.env";
      mode = "0600";
      owner = "kabilan";
      group = "users";
    };
    secrets."secrets/moberg/vpn/ca.age" = {
      file = ./secrets/moberg/vpn/ca.age;
      path = "${home}/.config/moberg/vpn/ca.crt";
      mode = "0600";
      owner = "kabilan";
      group = "users";
    };
    secrets."secrets/moberg/vpn/cert.age" = {
      file = mobergVpnCertFile;
      path = "${home}/.config/moberg/vpn/tony.crt";
      mode = "0600";
      owner = "kabilan";
      group = "users";
    };
    secrets."secrets/moberg/vpn/key.age" = {
      file = mobergVpnKeyFile;
      path = "${home}/.config/moberg/vpn/tony.key";
      mode = "0600";
      owner = "kabilan";
      group = "users";
    };
    secrets."secrets/moberg/vpn/ta.age" = {
      file = ./secrets/moberg/vpn/ta.age;
      path = "${home}/.config/moberg/vpn/ta.key";
      mode = "0600";
      owner = "kabilan";
      group = "users";
    };

    secrets."secrets/hark/e-boost-automations.curl.age" = lib.mkIf isHarkHost {
      file = ./secrets/hark/e-boost-automations.curl.age;
      path = "${home}/.config/hark/integrations/e-boost-automations.curl";
      mode = "0600";
      owner = "kabilan";
      group = "users";
    };

    secrets."secrets/hark/fleet-maintenance.curl.age" = lib.mkIf isHarkHost {
      file = ./secrets/hark/fleet-maintenance.curl.age;
      path = "${home}/.config/hark/integrations/fleet-maintenance.curl";
      mode = "0600";
      owner = "kabilan";
      group = "users";
    };

    secrets."secrets/hark/config.json.age" = lib.mkIf isHarkHost {
      file = harkConfigFile;
      path = "${home}/.config/hark/config.json";
      mode = "0600";
      owner = "kabilan";
      group = "users";
    };

    secrets."secrets/nix-access-tokens.age" = {
      file = ./secrets/nix-access-tokens.age;
      mode = "0400";
      owner = "root";
      group = "root";
    };
    secrets."secrets/nix-access-tokens-user.age" = {
      file = ./secrets/nix-access-tokens.age;
      mode = "0400";
      owner = "kabilan";
      group = "users";
    };
  };

  environment.etc."nix/access-tokens.conf".source =
    config.age.secrets."secrets/nix-access-tokens.age".path;

  nix.extraOptions = ''
    !include /etc/nix/access-tokens.conf
  '';

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };

    users.kabilan.imports = [
      ./home
      (
        { config, ... }:
        {
          xdg.configFile."nix/access-tokens.conf".source = config.lib.file.mkOutOfStoreSymlink userTokensPath;
          xdg.configFile."nix/nix.conf".text = ''
            !include access-tokens.conf
          '';
        }
      )
    ];
  };

  imports = [
    inputs.agenix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
  ];
}
