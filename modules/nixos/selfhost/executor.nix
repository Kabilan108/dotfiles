{ config, ... }:
{
  age.secrets.selfhost-executor-env.file = ../../../secrets/selfhost/executor-env.age;

  selfhost.tailnetServices.executor.port = 8302;

  virtualisation.oci-containers.containers.executor = {
    # digest-pinned; bump with bin/image-pins or the update-image-pins skill
    image = "ghcr.io/rhyssullivan/executor-selfhost:latest@sha256:c8dd83a5dba8ac992dfe1ded4aa65ae4e7f52ec31fddbe2af5b49ffebe5bbfa7";
    ports = [ "127.0.0.1:8302:4788" ];
    volumes = [ "/var/lib/executor:/data" ];
    environment = {
      EXECUTOR_WEB_BASE_URL = "https://executor.sole-pierce.ts.net";
      EXECUTOR_DISABLE_ANALYTICS = "1";
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
