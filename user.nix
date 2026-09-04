{
  config,
  pkgs,
  inputs,
  displayServer,
  waylandCompositor,
  ...
}:
let
  home = config.users.users.kabilan.home;
in
{
  users.users.kabilan = {
    isNormalUser = true;
    description = "Tony Kabilan Okeke";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "plugdev"
    ];
    shell = pkgs.bashInteractive;
    linger = true;
  };

  environment.systemPackages = [ pkgs.bashInteractive ];

  age = {
    identityPaths = [ "${home}/.ssh/id_ed25519" ];
    secretsDir = "/run/agenix";
    secrets."secrets/bashenv.age" = {
      file = ./secrets/bashenv.age;
      path = "${home}/.bashenv";
      mode = "0600";
      owner = "kabilan";
      group = "users";
    };
    secrets."secrets/discord-notify.age" = {
      file = ./secrets/discord-notify.age;
      path = "${home}/.config/discord-notify/channels.json";
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
    secrets."secrets/netrc.age" = {
      file = ./secrets/netrc.age;
      path = "${home}/.netrc";
      mode = "0600";
      owner = "kabilan";
      group = "users";
    };

    # .config/moberg dir
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
      file = ./secrets/moberg/vpn/cert.age;
      path = "${home}/.config/moberg/vpn/tony.crt";
      mode = "0600";
      owner = "kabilan";
      group = "users";
    };
    secrets."secrets/moberg/vpn/key.age" = {
      file = ./secrets/moberg/vpn/key.age;
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
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs displayServer waylandCompositor; };

    users.kabilan.imports = [ ./home ];
  };

  imports = [
    inputs.agenix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
  ];
}
