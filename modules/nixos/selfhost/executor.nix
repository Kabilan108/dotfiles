{ config, ... }:
{
  age.secrets.selfhost-executor-env.file = ../../../secrets/selfhost/executor-env.age;

  selfhost.tailnetServices.executor.port = 8302;

  virtualisation.oci-containers.containers.executor = {
    image = "ghcr.io/rhyssullivan/executor-selfhost:latest";
    ports = [ "127.0.0.1:8302:4788" ];
    volumes = [ "/var/lib/executor:/data" ];
    environment = {
      EXECUTOR_WEB_BASE_URL = "https://executor.sole-pierce.ts.net";
      # sandboxed code must not reach loopback: vaultwarden/jellyfin/siren live there
      EXECUTOR_ALLOW_LOCAL_NETWORK = "false";
    };
    extraOptions = [
      "--env"
      "EXECUTOR_SECRET_KEY"
      "--env"
      "BETTER_AUTH_SECRET"
      "--env"
      "EXECUTOR_BOOTSTRAP_ADMIN_EMAIL"
      "--env"
      "EXECUTOR_BOOTSTRAP_ADMIN_PASSWORD"
    ];
  };

  systemd.services.docker-executor.serviceConfig.EnvironmentFile =
    config.age.secrets.selfhost-executor-env.path;
}
