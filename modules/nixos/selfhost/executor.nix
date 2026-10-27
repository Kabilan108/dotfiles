{ config, ... }:
{
  age.secrets.selfhost-executor-env.file = ../../../secrets/selfhost/executor-env.age;

  selfhost.tailnetServices.executor.port = 8302;

  virtualisation.oci-containers.containers.executor = {
    # digest-pinned; bump with bin/image-pins or the update-image-pins skill
    image = "ghcr.io/usefulsoftwareco/executor-selfhost:v1.6.11@sha256:ea8b4d1019cc00c81cb4236d8edc07a12ac75ef465593b89ae652c0800cd33c1";
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
