{
  config,
  lib,
  pkgs,
  ...
}:
let
  cliproxyapi = pkgs.callPackage ../../../packages/cliproxyapi.nix { };
  migrateConfig = pkgs.callPackage ../../../packages/cliproxyapi-migrate.nix { inherit cliproxyapi; };
  configPath = "/var/lib/cliproxyapi/config.yaml";
  apiPort = 8317;
  inferencePort = 8320;
  adminPort = 8321;
  inferencePrefixes = [
    "/v1/"
    "/v1beta/"
    "/openai/v1/"
    "/backend-api/codex/"
  ];
  adminPrefixes = [
    "/v0/management/"
    "/v8/management/"
  ];
  cpaProxy = {
    proxyPass = "http://127.0.0.1:${toString apiPort}";
    proxyWebsockets = true;
    extraConfig = ''
      proxy_set_header Host $host;
      proxy_buffering off;
      proxy_request_buffering off;
      proxy_cache off;
      proxy_read_timeout 1h;
      proxy_send_timeout 1h;
      client_max_body_size 0;
    '';
  };
  loopbackVhost = port: locations: {
    listen = [
      {
        addr = "127.0.0.1";
        inherit port;
      }
    ];
    serverName = "_";
    extraConfig = ''
      access_log off;
      absolute_redirect off;
    '';
    locations = {
      "/".return = "404";
    }
    // locations;
  };
in
{
  age.secrets.selfhost-cliproxyapi-env.file = ../../../secrets/selfhost/cliproxyapi-env.age;

  selfhost.tailnetServices.cliproxyapi.port = inferencePort;
  selfhost.tailnetServices.cpa-admin.port = adminPort;

  services.nginx = {
    enable = true;
    virtualHosts.cliproxyapi-inference = loopbackVhost inferencePort (
      { "= /healthz" = cpaProxy; } // lib.genAttrs inferencePrefixes (_: cpaProxy)
    );
    virtualHosts.cliproxyapi-admin = loopbackVhost adminPort (
      {
        "= /".return = "302 /management.html";
        "= /management.html" = cpaProxy;
        "= /v1/models" = cpaProxy // {
          extraConfig = cpaProxy.extraConfig + ''
            limit_except GET {
              deny all;
            }
          '';
        };
      }
      // lib.genAttrs adminPrefixes (_: cpaProxy)
    );
  };

  users.users.cliproxyapi = {
    isSystemUser = true;
    group = "cliproxyapi";
  };
  users.groups.cliproxyapi = { };

  systemd.services.cliproxyapi = {
    description = "CLIProxyAPI model gateway";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.yq-go ];
    environment = {
      CLIPROXY_CONFIG = configPath;
      MANAGEMENT_STATIC_PATH = "${cliproxyapi.managementPanel}";
    };
    serviceConfig = {
      User = "cliproxyapi";
      Group = "cliproxyapi";
      StateDirectory = "cliproxyapi";
      StateDirectoryMode = "0700";
      WorkingDirectory = "/var/lib/cliproxyapi";
      UMask = "0077";
      EnvironmentFile = config.age.secrets.selfhost-cliproxyapi-env.path;
      ExecStart = "${lib.getExe cliproxyapi} --config ${configPath}";
      Restart = "on-failure";
      RestartSec = 5;

      NoNewPrivileges = true;
      CapabilityBoundingSet = "";
      AmbientCapabilities = "";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      PrivateUsers = true;
      ProtectProc = "invisible";
      ProcSubset = "pid";
      ProtectHostname = true;
      ProtectClock = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      RemoveIPC = true;
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
        "~@resources"
        "@chown"
      ];
      SystemCallErrorNumber = "EPERM";
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
        "AF_NETLINK"
      ];
    };
    preStart = ''
      if [[ ! -e "$CLIPROXY_CONFIG" ]]; then
        umask 077
        export CLIPROXY_MANAGEMENT_KEY
        yq -n '
          ."config-version" = 8 |
          .server.host = "127.0.0.1" |
          .server.port = ${toString apiPort} |
          .oauth."auth-dir" = "/var/lib/cliproxyapi/auth" |
          .access."api-keys" = ["claudex-tailnet"] |
          .management."allow-remote" = false |
          .management."secret-key" = strenv(CLIPROXY_MANAGEMENT_KEY) |
          .management."disable-control-panel" = false |
          .oauth."request-scoped-errors" = {} |
          .requests.payload.filter = [] |
          .observability.logs.debug = false |
          .observability.logs."logging-to-file" = false |
          .observability.usage."usage-statistics-enabled" = false
        ' > "$CLIPROXY_CONFIG"
      fi

      ${lib.getExe migrateConfig} "$CLIPROXY_CONFIG"

      yq -i '
        .routing.strategy = "round-robin" |
        .routing."session-affinity" = true |
        .routing."session-affinity-ttl" = "1h" |
        .observability.logs."logging-to-file" = false
      ' "$CLIPROXY_CONFIG"

      yq -i '
        .management."disable-auto-update-panel" = true |
        .management."allow-remote" = false
      ' "$CLIPROXY_CONFIG"

      export CLIPROXY_THREAD_RULE='{"status":404,"match":["thread_not_found","No thread state was found"],"action":"stop"}'
      yq -i '
        .oauth."request-scoped-errors".claude =
          ([env(CLIPROXY_THREAD_RULE)] + ((.oauth."request-scoped-errors".claude // []) | map(select(
            (.status == 404 and .action == "stop" and ((.match // []) | join("|")) == "thread_not_found|No thread state was found") | not
          ))))
      ' "$CLIPROXY_CONFIG"

      export CLIPROXY_THREAD_FILTER='{"models":[{"name":"claude-*","protocol":"claude","exist":["thread"]}],"params":["fallbacks"]}'
      yq -i '
        .requests.payload.filter =
          ([env(CLIPROXY_THREAD_FILTER)] + ((.requests.payload.filter // []) | map(select(
            ((.models | length) == 1 and .models[0].name == "claude-*" and .models[0].protocol == "claude" and
              ((.models[0].exist // []) | join("|")) == "thread" and ((.params // []) | join("|")) == "fallbacks") | not
          ))))
      ' "$CLIPROXY_CONFIG"
    '';
  };
}
