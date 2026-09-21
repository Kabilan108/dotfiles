{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.parakeet-redux;
  serverExecutable = "${cfg.projectDirectory}/.venv/bin/parakeet-redux-serve";
in
{
  options.dotfiles.services.parakeet-redux = {
    enable = lib.mkEnableOption "local Parakeet Redux transcription server";

    projectDirectory = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/experiments/parakeet-redux";
      description = "Path to the locked Parakeet Redux Python project and virtual environment.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8304;
      description = "Loopback port for the Parakeet Redux transcription endpoint.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.parakeet-redux = {
      Unit = {
        Description = "Local Parakeet Redux transcription server";
        Documentation = "https://huggingface.co/moondream/parakeet-redux";
        ConditionPathExists = serverExecutable;
      };

      Service = {
        Type = "simple";
        ExecStart = "${serverExecutable} --host 127.0.0.1 --port ${toString cfg.port} --device cpu";
        WorkingDirectory = cfg.projectDirectory;
        Restart = "on-failure";
        RestartSec = 5;

        Environment = [
          "DO_NOT_TRACK=1"
          "HF_HUB_DISABLE_TELEMETRY=1"
          "HF_HUB_OFFLINE=1"
          "PATH=${lib.makeBinPath [ pkgs.ffmpeg ]}"
          "PYTHONDONTWRITEBYTECODE=1"
        ];

        IPAddressAllow = "localhost";
        IPAddressDeny = "any";
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = "read-only";
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        UMask = "0077";
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
