{ config, inputs, ... }:
{
  imports = [ inputs.siren.nixosModules.default ];

  age.secrets.selfhost-siren-env.file = ../../../secrets/selfhost/siren-env.age;

  selfhost.tailnetServices.siren.port = 8301;

  services.siren = {
    enable = true;
    port = 8301;
    environmentFile = config.age.secrets.selfhost-siren-env.path;
    # shared host-wide model cache, so large models are stored once
    hfHome = "/vault/userdata/huggingface";
  };

  systemd.services.siren.environment = {
    SIREN_PARAKEET_CLAUDE_HINT = "true";
    TRITON_LIBCUDA_PATH = "/run/opengl-driver/lib";
  };

  # grant exactly the siren user access to the kabilan-owned cache; the
  # default (d:) entries make files created by other tools inherit it
  systemd.tmpfiles.rules = [
    "A+ /vault/userdata/huggingface - - - - u:siren:rwX,d:u:siren:rwX"
  ];
}
