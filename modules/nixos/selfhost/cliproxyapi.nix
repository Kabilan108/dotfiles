{
  config,
  lib,
  pkgs,
  ...
}:
let
  cliproxyapi = pkgs.callPackage ../../../packages/cliproxyapi.nix { };
  configPath = "/var/lib/cliproxyapi/config.yaml";
in
{
  age.secrets.selfhost-cliproxyapi-env.file = ../../../secrets/selfhost/cliproxyapi-env.age;

  selfhost.tailnetServices.cliproxyapi.port = 8317;

  systemd.services.cliproxyapi = {
    description = "CLIProxyAPI model gateway";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.yq-go ];
    environment.CLIPROXY_CONFIG = configPath;
    serviceConfig = {
      User = "kabilan";
      Group = "users";
      StateDirectory = "cliproxyapi";
      StateDirectoryMode = "0700";
      EnvironmentFile = config.age.secrets.selfhost-cliproxyapi-env.path;
      ExecStart = "${lib.getExe cliproxyapi} --config ${configPath}";
      Restart = "on-failure";
      RestartSec = 5;
    };
    preStart = ''
      if [[ ! -e "$CLIPROXY_CONFIG" ]]; then
        umask 077
        export CLIPROXY_MANAGEMENT_KEY
        yq -n '
          .host = "127.0.0.1" |
          .port = 8317 |
          ."auth-dir" = "/var/lib/cliproxyapi/auth" |
          ."api-keys" = ["claudex-tailnet"] |
          ."remote-management"."allow-remote" = true |
          ."remote-management"."secret-key" = strenv(CLIPROXY_MANAGEMENT_KEY) |
          ."remote-management"."disable-control-panel" = false |
          .debug = false |
          ."logging-to-file" = false |
          ."usage-statistics-enabled" = false
        ' > "$CLIPROXY_CONFIG"
      fi

      yq -i '
        .routing.strategy = "round-robin" |
        .routing."session-affinity" = true |
        .routing."session-affinity-ttl" = "1h"
      ' "$CLIPROXY_CONFIG"
    '';
  };
}
