{
  config,
  pkgs,
  inputs,
  theme,
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
  };

  environment.systemPackages = [ pkgs.bashInteractive ];

  age = {
    identityPaths = [ "${home}/.ssh/id_ed25519" ];
    secrets."secrets/env.age" = {
      file = ../secrets/env.age;
      path = "${home}/.bashenv";
      mode = "0600"; # read/write for owner only
      owner = "kabilan";
      group = "users";
    };
    secrets."secrets/rclone.conf" = {
      file = ../secrets/rclone.conf;
      path = "${home}/.config/rclone/rclone.conf";
      mode = "0600";
      owner = "kabilan";
      group = "users";
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs theme; };

    users.kabilan.imports = [
      ../desktop
      ../dev
    ];
  };

  imports = [
    inputs.agenix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
  ];
}
