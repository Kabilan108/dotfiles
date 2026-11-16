{ inputs, pkgs, ... }:
let
  # tleilax takes none of the shared overlays, so build atlas here with the
  # Pi's own package set, as the atlas overlay does elsewhere.
  atlas = pkgs.callPackage "${inputs.atlas}/nix/package.nix" { };
  port = 8303;
in
{
  # No tailnet service: only Executor on this box calls it, so the Jira and
  # Bitbucket tokens never leave the Pi. Stateless: every request carries its
  # own credentials in X-Atlas-* headers, and `mcp serve` skips the update
  # check and the disk cache.
  tleilax.executor.localServices.atlas = port;

  systemd.services.atlas = {
    description = "Atlas MCP server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      ExecStart = "${atlas}/bin/atlas mcp serve --addr 127.0.0.1:${toString port}";
      Restart = "on-failure";
      RestartSec = 5;

      DynamicUser = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectProc = "invisible";
      ProcSubset = "pid";
      ProtectHostname = true;
      ProtectClock = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      RemoveIPC = true;
      PrivateUsers = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
        "~@resources"
      ];
      CapabilityBoundingSet = "";
      AmbientCapabilities = "";
      UMask = "0077";
    };
  };
}
