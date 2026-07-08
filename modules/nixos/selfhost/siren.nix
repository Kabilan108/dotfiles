{ config, ... }:
{
  age.secrets.selfhost-siren-env.file = ../../../secrets/selfhost/siren-env.age;

  selfhost.tailnetServices.siren.port = 8301;

  # Image is built and pushed by local automation in the siren repo; the
  # generated unit uses `--pull missing`, so updates are deliberate:
  # build/pull a new image, then restart docker-siren.
  virtualisation.oci-containers.containers.siren = {
    image = "docker.io/kabilan108/siren:latest";
    ports = [ "127.0.0.1:8301:8000" ];
    volumes = [ "/vault/userdata/huggingface:/root/.cache/huggingface" ];
    extraOptions = [
      "--device=nvidia.com/gpu=all"
      "--env"
      "SIREN_API_KEY"
    ];
  };

  systemd.services.docker-siren.serviceConfig.EnvironmentFile =
    config.age.secrets.selfhost-siren-env.path;
}
