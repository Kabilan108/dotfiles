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
    environment = {
      CLIPROXY_CONFIG = configPath;
      MANAGEMENT_STATIC_PATH = "${cliproxyapi.managementPanel}";
    };
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
          .server.port = 8317 |
          .oauth."auth-dir" = "/var/lib/cliproxyapi/auth" |
          .access."api-keys" = ["claudex-tailnet"] |
          .management."allow-remote" = true |
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
        yq -i '.management."disable-auto-update-panel" = true' "$CLIPROXY_CONFIG"
      else
        yq -i '."remote-management"."disable-auto-update-panel" = true' "$CLIPROXY_CONFIG"
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
