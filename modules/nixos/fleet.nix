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

  programs.ssh.knownHosts = lib.mapAttrs (name: host: {
    hostNames = [
      name
      "${name}.${fleet.tailnet}"
      host.tailscaleIp
    ];
    publicKey = host.hostPubkey;
  }) knownFleetHosts;
}
