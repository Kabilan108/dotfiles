{
  config,
  lib,
  ...
}:
let
  fleet = import ../../lib/fleet.nix;
  thisHost = config.networking.hostName;
  knownFleetHosts = lib.filterAttrs (_: host: host.hostPubkey != null) fleet.hosts;

  home = config.users.users.kabilan.home;
  keySecret = name: {
    name = "ssh/${thisHost}/${name}";
    value = {
      file = ../../secrets/ssh + "/${thisHost}/${name}.age";
      path = "${home}/.ssh/${name}";
      mode = "0600";
      owner = "kabilan";
      group = "users";
    };
  };
  existingKeyFiles = builtins.filter (
    name: builtins.pathExists (../../secrets/ssh + "/${thisHost}/${name}.age")
  ) (fleet.hosts.${thisHost}.sshKeyFiles or [ ]);
in
{
  users.users.kabilan.openssh.authorizedKeys.keys = lib.mkIf (fleet.hosts ? ${thisHost}) (
    fleet.authorizedKeysFor thisHost
  );

  age.secrets =
    builtins.listToAttrs (map keySecret existingKeyFiles)
    // lib.optionalAttrs (builtins.pathExists ../../secrets/ssh/private-config.age) {
      "ssh/private-config" = {
        file = ../../secrets/ssh/private-config.age;
        path = "${home}/.ssh/config.d/private";
        mode = "0600";
        owner = "kabilan";
        group = "users";
      };
    };

  programs.ssh.knownHosts =
    lib.mapAttrs (name: host: {
      hostNames = [
        name
        "${name}.${fleet.tailnet}"
        host.tailscaleIp
      ];
      publicKey = host.hostPubkey;
    }) knownFleetHosts
    // {
      # Published at https://bitbucket.org/site/ssh; fingerprints verified against
      # https://support.atlassian.com/bitbucket-cloud/docs/configure-ssh-and-two-step-verification/
      bitbucket-ed25519 = {
        hostNames = [ "ssh.bitbucket.org" ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIazEu89wgQZ4bqs3d63QSMzYVa0MuJ2e2gKTKqu+UUO";
      };
      bitbucket-ecdsa = {
        hostNames = [ "ssh.bitbucket.org" ];
        publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBPIQmuzMBuKdWeF4+a2sjSSpBK0iqitSQ+5BM9KhpexuGt20JpTVM7u5BDZngncgrqDMbWdxMWWOGtZ9UgbqgZE=";
      };
      bitbucket-rsa = {
        hostNames = [ "ssh.bitbucket.org" ];
        publicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDQeJzhupRu0u0cdegZIa8e86EG2qOCsIsD1Xw0xSeiPDlCr7kq97NLmMbpKTX6Esc30NuoqEEHCuc7yWtwp8dI76EEEB1VqY9QJq6vk+aySyboD5QF61I/1WeTwu+deCbgKMGbUijeXhtfbxSxm6JwGrXrhBdofTsbKRUsrN1WoNgUa8uqN1Vx6WAJw1JHPhglEGGHea6QICwJOAr/6mrui/oB7pkaWKHj3z7d1IC4KWLtY47elvjbaTlkN04Kc/5LFEirorGYVbt15kAUlqGM65pk6ZBxtaO3+30LVlORZkxOh+LKL/BvbZ/iRNhItLqNyieoQj/uh/7Iv4uyH/cV/0b4WDSd3DptigWq84lJubb9t/DnZlrJazxyDCulTmKdOR7vs9gMTo+uoIrPSb8ScTtvw65+odKAlBj59dhnVp9zd7QUojOpXlL62Aw56U4oO+FALuevvMjiWeavKhJqlR7i5n9srYcrNV7ttmDw7kf/97P5zauIhxcjX+xHv4M=";
      };
    };
}
