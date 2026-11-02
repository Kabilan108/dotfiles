{
  config,
  lib,
  pkgs,
  ...
}:
let
  cliproxyapi = pkgs.callPackage ../../../packages/cliproxyapi.nix { };
  configPath = "/var/lib/cliproxyapi/config.yaml";
  # CPA serves inference and management on one listener. Local callers such as
  # sera use it directly; the tailnet reaches only the inference front.
  apiPort = 8317;
  inferencePort = 8320;
  inferencePrefixes = [
    "/v1/"
    "/v1beta/"
    "/openai/v1/"
    "/backend-api/codex/"
  ];
  inferenceProxy = {
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
in
{
  age.secrets.selfhost-cliproxyapi-env.file = ../../../secrets/selfhost/cliproxyapi-env.age;

  selfhost.tailnetServices.cliproxyapi.port = inferencePort;

  # Tailscale Serve proxies from loopback, so CPA sees every tailnet request as
  # local and allow-remote alone cannot refuse it. Forward inference routes only.
  services.nginx = {
    enable = true;
    virtualHosts.cliproxyapi-inference = {
      listen = [
        {
          addr = "127.0.0.1";
          port = inferencePort;
        }
      ];
      serverName = "_";
      extraConfig = ''
        access_log off;
      '';
      locations = {
        "/".return = "404";
        "= /healthz" = inferenceProxy;
      }
      // lib.genAttrs inferencePrefixes (_: inferenceProxy);
    };
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
      # systemd re-owns the whole tree when the directory's owner differs from
      # User=/Group=, which moves the existing kabilan-owned state on first start.
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
      # yq -i in preStart fchowns its temp file to the current owner, which
      # ~@privileged would kill. Without capabilities chown cannot change owners.
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
        "~@resources"
        "@chown"
      ];
      # Fail a filtered call instead of killing the gateway mid-session.
      SystemCallErrorNumber = "EPERM";
      # Upstream providers are on the internet; AF_NETLINK serves Go's interface lookups.
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
        "AF_NETLINK"
      ];
    };
    preStart = ''
      # Preserve the operator configuration before applying the v8 recovery settings.
      if [[ -e "$CLIPROXY_CONFIG" && ! -e "$CLIPROXY_CONFIG.pre-v8" ]]; then
        install -m 0600 "$CLIPROXY_CONFIG" "$CLIPROXY_CONFIG.pre-v8"
      fi

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

      yq -i '
        .routing.strategy = "round-robin" |
        .routing."session-affinity" = true |
        .routing."session-affinity-ttl" = "1h"
      ' "$CLIPROXY_CONFIG"

      # Keep existing files in their current layout until a v8 API write migrates them.
      # Never replace the management object: it contains the operator-managed key.
      if yq -e 'has("management")' "$CLIPROXY_CONFIG" >/dev/null 2>&1; then
        yq -i '
          .management."disable-auto-update-panel" = true |
          .management."allow-remote" = false
        ' "$CLIPROXY_CONFIG"
      else
        yq -i '
          ."remote-management"."disable-auto-update-panel" = true |
          ."remote-management"."allow-remote" = false
        ' "$CLIPROXY_CONFIG"
      fi

      # A missing conversation is a request fault, not a reason to cool the account.
      # Prepend the rule so broader operator rules cannot turn it into a cooldown.
      export CLIPROXY_THREAD_RULE='{"status":404,"match":["thread_not_found","No thread state was found"],"action":"stop"}'
      if yq -e '.oauth | has("request-scoped-errors")' "$CLIPROXY_CONFIG" >/dev/null 2>&1; then
        yq -i '
          .oauth."request-scoped-errors".claude =
            ([env(CLIPROXY_THREAD_RULE)] + ((.oauth."request-scoped-errors".claude // []) | map(select(
              (.status == 404 and .action == "stop" and ((.match // []) | join("|")) == "thread_not_found|No thread state was found") | not
            ))))
        ' "$CLIPROXY_CONFIG"
      else
        yq -i '
          ."oauth-request-scoped-errors".claude =
            ([env(CLIPROXY_THREAD_RULE)] + ((."oauth-request-scoped-errors".claude // []) | map(select(
              (.status == 404 and .action == "stop" and ((.match // []) | join("|")) == "thread_not_found|No thread state was found") | not
            ))))
        ' "$CLIPROXY_CONFIG"
      fi

      # Anthropic rejects thread + fallbacks. Preserve fallbacks on unthreaded calls.
      export CLIPROXY_THREAD_FILTER='{"models":[{"name":"claude-*","protocol":"claude","exist":["thread"]}],"params":["fallbacks"]}'
      if yq -e '.requests | has("payload")' "$CLIPROXY_CONFIG" >/dev/null 2>&1; then
        yq -i '
          .requests.payload.filter =
            ([env(CLIPROXY_THREAD_FILTER)] + ((.requests.payload.filter // []) | map(select(
              ((.models | length) == 1 and .models[0].name == "claude-*" and .models[0].protocol == "claude" and
                ((.models[0].exist // []) | join("|")) == "thread" and ((.params // []) | join("|")) == "fallbacks") | not
            ))))
        ' "$CLIPROXY_CONFIG"
      else
        yq -i '
          .payload.filter =
            ([env(CLIPROXY_THREAD_FILTER)] + ((.payload.filter // []) | map(select(
              ((.models | length) == 1 and .models[0].name == "claude-*" and .models[0].protocol == "claude" and
                ((.models[0].exist // []) | join("|")) == "thread" and ((.params // []) | join("|")) == "fallbacks") | not
            ))))
        ' "$CLIPROXY_CONFIG"
      fi
    '';
  };
}
