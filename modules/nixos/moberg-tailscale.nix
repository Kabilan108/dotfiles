{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.mobergTailscale;
  socketPath = "/run/tailscale-moberg/tailscaled.sock";
  companyCli = pkgs.writeShellApplication {
    name = "tailscale-moberg";
    text = ''
      exec ${cfg.package}/bin/tailscale --socket=${socketPath} "$@"
    '';
  };
  companyEnroll = pkgs.writeShellApplication {
    name = "moberg-tailscale-enroll";
    text = ''
      exec ${cfg.package}/bin/tailscale --socket=${socketPath} up \
        --hostname=${lib.escapeShellArg cfg.nodeName} \
        --operator=${lib.escapeShellArg cfg.operator} \
        --accept-dns=false --accept-routes=false --shields-up=true \
        --advertise-tags=${lib.escapeShellArg cfg.tag} "$@"
    '';
  };
  companyConnect = pkgs.writeShellApplication {
    name = "moberg-tailnet";
    text = ''
      if [[ $# != 2 ]]; then
        echo "Usage: moberg-tailnet HOST PORT" >&2
        exit 2
      fi
      exec ${pkgs.netcat-openbsd}/bin/nc -N -X 5 \
        -x 127.0.0.1:${toString cfg.socksPort} -- "$1" "$2"
    '';
  };
in
{
  options.dotfiles.mobergTailscale = {
    enable = lib.mkEnableOption "an independent userspace Tailscale client for Moberg support";
    package = lib.mkPackageOption pkgs "tailscale" { };
    operator = lib.mkOption {
      type = lib.types.str;
      default = "kabilan";
      description = "Local user allowed to administer the company client after enrollment.";
    };
    nodeName = lib.mkOption {
      type = lib.types.str;
      default = "tony-okeke-${config.networking.hostName}";
      description = "Distinct company-tailnet node name for this machine's support client.";
    };
    tag = lib.mkOption {
      type = lib.types.str;
      default = "tag:optimice-support";
      description = "Company service identity; define this tag in company policy before enrollment.";
    };
    socksPort = lib.mkOption {
      type = lib.types.port;
      default = 1055;
      description = "Loopback SOCKS5 port used by moberg-tailnet on this machine.";
    };
    udpPort = lib.mkOption {
      type = lib.types.port;
      default = 41642;
      description = "Separate UDP peer-connectivity port for the company client.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.socksPort > 1023 && cfg.udpPort > 1023;
        message = "The non-root Moberg Tailscale client requires unprivileged ports.";
      }
    ];

    users.groups.tailscale-moberg = { };
    users.users.tailscale-moberg = {
      isSystemUser = true;
      group = "tailscale-moberg";
      home = "/var/lib/tailscale-moberg";
    };

    environment.systemPackages = [
      companyCli
      companyEnroll
      companyConnect
    ];
    networking.firewall.allowedUDPPorts = [ cfg.udpPort ];

    systemd.services.tailscale-moberg = {
      description = "Independent Moberg Tailscale support client";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "simple";
        User = "tailscale-moberg";
        Group = "tailscale-moberg";
        StateDirectory = "tailscale-moberg";
        StateDirectoryMode = "0700";
        RuntimeDirectory = "tailscale-moberg";
        RuntimeDirectoryMode = "0755";
        UMask = "0077";
        ExecStart = lib.concatStringsSep " " [
          "${cfg.package}/bin/tailscaled"
          "--tun=userspace-networking"
          "--socket=${socketPath}"
          "--statedir=/var/lib/tailscale-moberg"
          "--socks5-server=127.0.0.1:${toString cfg.socksPort}"
          "--port=${toString cfg.udpPort}"
          "--syspolicy-file="
        ];
        Restart = "on-failure";
        RestartSec = 5;
        NoNewPrivileges = true;
        CapabilityBoundingSet = "";
        AmbientCapabilities = "";
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictRealtime = true;
        LockPersonality = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
          "AF_NETLINK"
        ];
      };
    };
  };
}
