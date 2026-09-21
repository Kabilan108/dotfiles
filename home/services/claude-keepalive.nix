{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.claude-keepalive;
  claudeKeepalive = pkgs.writeShellScript "claude-keepalive" ''
    set -euo pipefail

    ${pkgs.coreutils}/bin/install -m 0600 \
      "$HOME/.claude/.credentials.json" \
      "$RUNTIME_DIRECTORY/.credentials.json"

    export CLAUDE_CONFIG_DIR="$RUNTIME_DIRECTORY"
    exec "$HOME/.local/bin/claude" \
      --model haiku \
      --safe-mode \
      --strict-mcp-config \
      --mcp-config '{"mcpServers":{}}' \
      --tools "" \
      --permission-mode dontAsk \
      --permission-prompts none \
      --disable-slash-commands \
      --no-session-persistence \
      --print 'Reply with exactly: hello'
  '';
in
{
  options.dotfiles.services.claude-keepalive.enable =
    lib.mkEnableOption "periodic Claude Haiku keepalive prompts";

  config = lib.mkIf cfg.enable {
    systemd.user.services.claude-keepalive = {
      Unit = {
        Description = "Send a throwaway Claude Haiku prompt";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };

      Service = {
        Type = "oneshot";
        ExecStart = claudeKeepalive;
        TimeoutStartSec = "2m";
        RuntimeDirectory = "claude-keepalive";
        RuntimeDirectoryMode = "0700";
        UMask = "0077";

        # Claude gets a disposable credential copy and no writable view of the
        # real home directory. Its built-in tools and MCP servers are disabled
        # separately in the command above.
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        NoNewPrivileges = true;
        CapabilityBoundingSet = "";
        SystemCallArchitectures = "native";

        StandardOutput = "null";
        StandardError = "journal";
      };
    };

    systemd.user.timers.claude-keepalive = {
      Unit.Description = "Keep the Claude five-hour usage window fresh";
      Timer = {
        OnBootSec = "2m";
        # Jitter plus timer coalescing still keeps the interval at five hours
        # or less.
        OnUnitActiveSec = "4h54m";
        RandomizedDelaySec = "5m";
        AccuracySec = "1m";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
