{
  lib,
  pkgs,
  ...
}:
let
  port = 8787;
  project = "/home/kabilan/experiments/hark";
  website = "${project}/apps/website";
  entrypoint = "${website}/dist/server/index.js";
  dataDir = "/vault/userdata/hark";
  environmentFile = "${dataDir}/secrets/backend.env";
in
{
  selfhost.tailnetServices.hark.port = port;

  systemd.services.hark = {
    description = "Hark Android backend";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = [
      entrypoint
      environmentFile
    ];
    environment = {
      HOST = "127.0.0.1";
      PORT = toString port;
      DATABASE_URL = "${dataDir}/hark.sqlite";
      NODE_ENV = "production";
    };
    serviceConfig = {
      User = "kabilan";
      Group = "users";
      WorkingDirectory = website;
      EnvironmentFile = environmentFile;
      ExecStart = "${lib.getExe pkgs.nodejs_24} ${entrypoint}";
      Restart = "on-failure";
      RestartSec = 5;
      TimeoutStopSec = 30;
      UMask = "0077";

      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      ReadWritePaths = [ dataDir ];
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      ProtectHostname = true;
      RestrictSUIDSGID = true;
      RestrictRealtime = true;
      LockPersonality = true;
      CapabilityBoundingSet = "";
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
      ];
    };
  };
}
