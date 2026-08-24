{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  port = 8303;
  modelRoot = "/vault/userdata/models";
  qwen38Dir = "${modelRoot}/qwen3.8-27b";
  qwen38UncensoredDir = "${modelRoot}/qwen3.8-27b-uncensored-orcarouter";
  llamaCpp = inputs.llama-cpp.packages.${pkgs.stdenv.hostPlatform.system}.cuda;
  qwen38MtpModel = "${qwen38Dir}/MTP/mtp-Qwen3.8-27B-Q4_0.gguf";
  modelServiceNames = [
    "llamacpp"
    "llamacpp-qwen38-q4"
    "llamacpp-qwen38-uncensored-q5"
    "llamacpp-qwen38-uncensored-q4"
  ];
  conflictsFor =
    serviceName:
    [ "siren.service" ] ++ map (name: "${name}.service") (lib.remove serviceName modelServiceNames);

  mkServerService =
    {
      description,
      model,
      modelAlias,
      conflicts,
      speculativeModel ? null,
      extraArgs ? [ ],
    }:
    {
      inherit description conflicts;
      after = [ "network.target" ];
      unitConfig.ConditionPathExists = [
        model
      ]
      ++ lib.optional (speculativeModel != null) speculativeModel;
      environment = {
        DO_NOT_TRACK = "1";
        HF_HUB_DISABLE_TELEMETRY = "1";
        HF_HUB_OFFLINE = "1";
      };
      serviceConfig = {
        User = "llamacpp";
        Group = "llamacpp";
        ExecStart = lib.escapeShellArgs (
          [
            "${llamaCpp}/bin/llama-server"
            "--model"
            model
            "--alias"
            modelAlias
            "--host"
            "127.0.0.1"
            "--port"
            (toString port)
            "--offline"
            "--ctx-size"
            "32768"
            "--parallel"
            "1"
            "--n-gpu-layers"
            "all"
            "--flash-attn"
            "on"
            "--cache-type-k"
            "q8_0"
            "--cache-type-v"
            "q8_0"
          ]
          ++ lib.optionals (speculativeModel != null) [
            "--spec-type"
            "draft-mtp"
            "--spec-draft-model"
            speculativeModel
            "--spec-draft-n-max"
            "1"
            "--spec-draft-ngl"
            "all"
          ]
          ++ [
            "--no-slots"
            "--no-cors-credentials"
            "--cors-origins"
            "https://llamacpp.sole-pierce.ts.net"
            "--no-ui-mcp-proxy"
            "--no-agent"
            "--log-disable"
          ]
          ++ extraArgs
        );
        Restart = "on-failure";
        RestartSec = 5;
        UMask = "0077";

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        ProtectHostname = true;
        RestrictSUIDSGID = true;
        RestrictRealtime = true;
        ReadOnlyPaths = [ modelRoot ];
        IPAddressDeny = "any";
        IPAddressAllow = [ "localhost" ];
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
      };
    };
in
{
  selfhost.tailnetServices.llamacpp.port = port;

  users.groups.llamacpp = { };
  users.users.llamacpp = {
    isSystemUser = true;
    group = "llamacpp";
    extraGroups = [
      "video"
      "render"
    ];
  };

  # The engine keeps a generic service name. Each additional checkpoint can be
  # expressed as another profile using mkServerService without duplicating the
  # privacy, GPU, and hardening policy.
  systemd.services.llamacpp = mkServerService {
    description = "llama.cpp server: Qwen3.8 27B Q5_K_M";
    model = "${qwen38Dir}/Qwen3.8-27B-UD-Q5_K_M.gguf";
    modelAlias = "qwen3.8-27b";
    speculativeModel = qwen38MtpModel;
    conflicts = conflictsFor "llamacpp";
  };

  systemd.services.llamacpp-qwen38-q4 = mkServerService {
    description = "llama.cpp server: Qwen3.8 27B Q4_K_M";
    model = "${qwen38Dir}/Qwen3.8-27B-UD-Q4_K_M.gguf";
    modelAlias = "qwen3.8-27b";
    speculativeModel = qwen38MtpModel;
    conflicts = conflictsFor "llamacpp-qwen38-q4";
  };

  systemd.services.llamacpp-qwen38-uncensored-q5 = mkServerService {
    description = "llama.cpp server: OrcaRouter Qwen3.8 27B Uncensored Q5_K_M";
    model = "${qwen38UncensoredDir}/Qwen3.8-27B-Uncensored-Q5_K_M.gguf";
    modelAlias = "qwen3.8-27b-uncensored";
    conflicts = conflictsFor "llamacpp-qwen38-uncensored-q5";
    extraArgs = [
      "--spec-type"
      "draft-mtp"
      "--spec-draft-n-max"
      "1"
    ];
  };

  systemd.services.llamacpp-qwen38-uncensored-q4 = mkServerService {
    description = "llama.cpp server: OrcaRouter Qwen3.8 27B Uncensored Q4_K_M";
    model = "${qwen38UncensoredDir}/Qwen3.8-27B-Uncensored-Q4_K_M.gguf";
    modelAlias = "qwen3.8-27b-uncensored";
    conflicts = conflictsFor "llamacpp-qwen38-uncensored-q4";
    extraArgs = [
      "--spec-type"
      "draft-mtp"
      "--spec-draft-n-max"
      "1"
    ];
  };

  systemd.services.siren.conflicts = map (name: "${name}.service") modelServiceNames;
}
