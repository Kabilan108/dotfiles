{ config, pkgs, ... }:
{
  systemd.services.cpa-usage-front = {
    description = "Account list and usage lookups for sera";
    after = [ "cliproxyapi.service" ];
    wants = [ "cliproxyapi.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 -I ${../../../packages/cpa-usage-front.py}";
      DynamicUser = true;
      EnvironmentFile = config.age.secrets.selfhost-cliproxyapi-env.path;
      IPAddressDeny = "any";
      IPAddressAllow = "localhost";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
