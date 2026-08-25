{ pkgs, ... }:
let
  dockerUserFirewall = pkgs.writeShellApplication {
    name = "docker-user-firewall";
    runtimeInputs = [ pkgs.iptables ];
    text = builtins.readFile ./docker-user-firewall.sh;
  };
in
{
  boot.kernel.sysctl = {
    "fs.inotify.max_user_instances" = 524288;
    "fs.inotify.max_user_watches" = 524288;
  };

  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      data-root = "/vault/userdata/docker";
      ip = "127.0.0.1";
    };
  };

  systemd.services.docker-user-firewall = {
    description = "Restrict Docker-published ports on physical interfaces";
    wantedBy = [ "multi-user.target" ];
    after = [
      "docker.service"
      "firewall.service"
    ];
    requires = [ "docker.service" ];
    partOf = [
      "docker.service"
      "firewall.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${dockerUserFirewall}/bin/docker-user-firewall install";
      ExecStop = "${dockerUserFirewall}/bin/docker-user-firewall remove";
    };
  };
}
