{ config, pkgs, ... }:
let
  discordNotify = pkgs.writeShellApplication {
    name = "discord-notify-service";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${../../../packages/discord-notify-service.py} "$@"
    '';
  };
in
{
  age.secrets.selfhost-discord-notify-env.file = ../../../secrets/selfhost/discord-notify-env.age;

  selfhost.tailnetServices.discord-notify.port = 8303;

  systemd.services.discord-notify = {
    description = "Discord notification gateway";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      DynamicUser = true;
      EnvironmentFile = config.age.secrets.selfhost-discord-notify-env.path;
      ExecStart = "${discordNotify}/bin/discord-notify-service --host 127.0.0.1 --port 8303";
      Restart = "on-failure";
      RestartSec = 5;
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
      ];
      RestrictNamespaces = true;
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
    };
  };
}
