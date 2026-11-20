{ config, inputs, ... }:
{
  imports = [ inputs.siren.nixosModules.default ];

  age.secrets.selfhost-siren-env.file = ../../../secrets/selfhost/siren-env.age;

  selfhost.tailnetServices.siren.port = 8301;

  services.siren = {
    enable = true;
    port = 8301;
    environmentFile = config.age.secrets.selfhost-siren-env.path;
    hfHome = "/vault/userdata/huggingface";
  };

  systemd.services.siren.environment = {
    SIREN_PARAKEET_BOOST_TERMS = builtins.toJSON [
      "Claude"
      "Claude Code"
      "Codex"
      "OpenCode"
      "CodeRabbit"
      "T3 Code"
      "Niri"
      "Hyprland"
      "Omarchy"
      "Ghostty"
      "Tailscale"
      "agenix"
      "Stillsuit"
      "PageBin"
      "Hark"
      "Jacurutu"
      "Jupyter"
      "Vaultwarden"
      "Bitbucket"
      "Moberg"
      "qEEG"
      "CNSUtils"
      "E-BOOST"
      "PRECICECAP"
      "TrackTBI"
      "IntelliVue"
      "Masimo"
      "Zujun"
      "Ribal"
      "Arpit"
      "Hruday"
      "Sai"
    ];
    SIREN_PARAKEET_BOOST_CONTEXT_SCORE = "0.05";
    SIREN_PARAKEET_BOOST_DEPTH_SCALING = "40.0";
    SIREN_PARAKEET_BOOST_ALPHA = "1.0";
    SIREN_SPEAKER_SMOOTHING = "true";
    TRITON_LIBCUDA_PATH = "/run/opengl-driver/lib";
    SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
    REQUESTS_CA_BUNDLE = "/etc/ssl/certs/ca-certificates.crt";
    HF_TOKEN_PATH = "/var/lib/siren/hf-token";
  };

  systemd.tmpfiles.rules = [
    "A+ /vault/userdata/huggingface - - - - u:siren:rwX,d:u:siren:rwX,m::rwX"
  ];
}
