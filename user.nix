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
    secrets."secrets/env.age" = {
      file = ./secrets/env.age;
      path = "${home}/.bashenv";
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
    secrets."secrets/gog-creds" = {
      file = ./secrets/gog-creds;
      path = "${home}/.config/gogcli/credentials.json";
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
