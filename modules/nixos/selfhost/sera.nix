{
  config,
  lib,
  pkgs,
  ...
}:
let
  python = pkgs.python3.withPackages (p: [ p.pyserial ]);
  project = "/home/kabilan/experiments/esp32/collector";
in
{
  systemd.services.sera = {
    description = "Sera quota companion USB collector";
    wantedBy = [ "multi-user.target" ];
    after = [ "cliproxyapi.service" ];
    wants = [ "cliproxyapi.service" ];
    environment = {
      PYTHONPATH = "${project}/src";
      PYTHONDONTWRITEBYTECODE = "1";
      PYTHONUNBUFFERED = "1";
      PYTHONTZPATH = "${pkgs.tzdata}/share/zoneinfo";
    };
    serviceConfig = {
      User = "kabilan";
      Group = "users";
      SupplementaryGroups = [ "dialout" ];
      WorkingDirectory = project;
      ExecStart = "${lib.getExe python} -m sera_collector.bridge --key-env-file %d/proxy-env --state-file /var/lib/sera/state.sqlite --status-file /var/lib/sera/status.json";
      LoadCredential = [ "proxy-env:${config.age.secrets.selfhost-cliproxyapi-env.path}" ];
      StateDirectory = "sera";
      StateDirectoryMode = "0700";
      UMask = "0077";
      Restart = "always";
      RestartSec = 5;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      PrivateTmp = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
      ];
      IPAddressDeny = "any";
      IPAddressAllow = "localhost";
      DevicePolicy = "closed";
      DeviceAllow = [ "char-ttyACM rw" ];
    };
  };
}
