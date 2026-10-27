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
    # The venv's certifi comes from siren's uv.lock; trust the NixOS store instead
    # so CA distrusts (e.g. the Oct 2026 eMudhra compromise) apply on rebuild.
    SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
    REQUESTS_CA_BUNDLE = "/etc/ssl/certs/ca-certificates.crt";
    # Share the model cache, not the login: siren's models are public, so it
    # downloads anonymously. huggingface_hub treats a missing token file as no
    # token; put HF_TOKEN in siren-env.age if a gated model is ever needed.
    HF_TOKEN_PATH = "/var/lib/siren/hf-token";
  };

  # grant exactly the siren user access to the kabilan-owned cache; the
  # default (d:) entries make files created by other tools inherit it.
  # m::rwX restores the ACL mask, which any chmod 700/600 in the tree zeroes
  # (that silently revokes siren's entry); tmpfiles re-applies it on boot and switch.
  systemd.tmpfiles.rules = [
    "A+ /vault/userdata/huggingface - - - - u:siren:rwX,d:u:siren:rwX,m::rwX"
  ];
}
