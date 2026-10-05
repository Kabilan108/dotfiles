{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.docker.rootlessDevelopment;
  developmentSocket = "unix:///run/user/${toString config.users.users.kabilan.uid}/docker.sock";
  dockerUserFirewall = pkgs.writeShellApplication {
    name = "docker-user-firewall";
    runtimeInputs = [ pkgs.iptables ];
    text = builtins.readFile ./docker-user-firewall.sh;
  };
  rootfulStorageGuard = pkgs.writeText "docker-storage-guard.py" (
    builtins.readFile ./docker-storage-guard.py
  );
in
{
  options.dotfiles.docker.rootlessDevelopment = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use a separate rootless Docker daemon for user development";
    };
    allowRootfulUserAccess = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Grant the development user privileged Docker-group access during an
        explicitly staged migration or a reviewed host exception. Remove a
        migration override after verified restoration and before reboot.
      '';
    };
  };

  config = {
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
      rootless = lib.mkIf cfg.enable {
        enable = true;
        daemon.settings = {
          data-root = "/vault/userdata/docker-rootless";
          ip = "127.0.0.1";
        };
      };
    };

    systemd.tmpfiles.rules = lib.mkIf cfg.enable [
      "d /vault/userdata/docker-rootless 0700 kabilan users -"
    ];
    users.users.kabilan.uid = lib.mkIf cfg.enable (lib.mkDefault 1000);
    systemd.user.services.docker.unitConfig.ConditionUser = lib.mkIf cfg.enable (lib.mkForce "kabilan");
    systemd.services.docker = lib.mkIf cfg.enable {
      # Load the new checks on the next start without restarting live Executor.
      restartIfChanged = false;
      unitConfig.RequiresMountsFor = "/vault/userdata/docker";
      after = [ "systemd-tmpfiles-setup.service" ];
      preStart = "${pkgs.python3}/bin/python -I -S ${rootfulStorageGuard}";
    };
    home-manager.users.kabilan = lib.mkIf cfg.enable {
      xdg.configFile."moberg/docker.toml".text = ''
        host = "${developmentSocket}"
      '';
      home.sessionVariables = {
        DOCKER_HOST = developmentSocket;
        DEV_DOCKER_HOST = developmentSocket;
      };
      dotfiles.services.moberg.devMaintenance.dockerHost = developmentSocket;
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
  };
}
