# Executor, moved here from sietch in stage 5
# (docs/tleilax-credentials-move.md). It starts from an empty database, so the
# first start needs an explicit marker file; after that it needs its database.
#
# The container runs in its own network namespace ("executor"), shared only
# with the office VPN and the proxy described below. From there it reaches:
# - the internet, through a veth pair and NAT on the host;
# - the office subnet, over the Moberg OpenVPN tunnel, once its credential
#   exists;
# and nothing else: not the LAN, the tailnet, or the host's own services.
# Tailscale Serve reaches it through a socket on the host's loopback that
# systemd-socket-proxyd forwards into the namespace.
{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.executor;
  lan = import ./lan.nix;

  netns = "executor";
  netnsPath = "/run/netns/${netns}";
  hostVeth = "vex-host";
  nsVeth = "vex-ns";
  hostAddress = "10.231.0.1";
  nsAddress = "10.231.0.2";

  # Tailscale Serve connects to servePort on the host's loopback; Executor
  # listens on backendPort on the namespace's loopback.
  servePort = 8302;
  backendPort = 4788;

  dataDir = "/var/lib/executor";
  firstStart = "${dataDir}/initialize";

  vpnSecret = ../../secrets/tleilax/executor-vpn.age;

  requiredEnv = [
    "EXECUTOR_SECRET_KEY"
    "BETTER_AUTH_SECRET"
    "EXECUTOR_BOOTSTRAP_ADMIN_EMAIL"
    "EXECUTOR_BOOTSTRAP_ADMIN_PASSWORD"
  ];

  # Executor makes and keeps its own keys when the first two are empty, and
  # without a bootstrap admin the first visitor claims the instance.
  preStart = pkgs.writeShellScript "executor-check-environment" ''
    for name in ${lib.concatStringsSep " " requiredEnv}; do
      value=''${!name-}
      if [ -z "$value" ] || [ "$value" = REPLACE_ME ]; then
        echo "executor: $name is unset or still the placeholder" >&2
        exit 1
      fi
    done
    rm -f ${firstStart}
  '';

  # Inside the namespace: nothing may open a connection to it, from the
  # tunnel or the veth, and it routes nothing between them.
  netnsRules = pkgs.writeText "executor-netns.nft" ''
    table inet executor {
      chain input {
        type filter hook input priority filter; policy drop;
        iifname "lo" accept
        ct state established,related accept
      }
      chain forward {
        type filter hook forward priority filter; policy drop;
      }
    }
  '';

  # Private, shared, link-local and multicast ranges: the LAN, the tailnet
  # (100.64.0.0/10) and anything else that isn't the internet.
  notInternet = lib.concatStringsSep ", " [
    "0.0.0.0/8"
    "10.0.0.0/8"
    "100.64.0.0/10"
    "127.0.0.0/8"
    "169.254.0.0/16"
    "172.16.0.0/12"
    "192.0.0.0/24"
    "192.168.0.0/16"
    "198.18.0.0/15"
    "224.0.0.0/3"
  ];
in
{
  options.dotfiles.executor = {
    environmentFile = lib.mkOption {
      type = lib.types.str;
      description = "Environment file with ${lib.concatStringsSep ", " requiredEnv}.";
    };
    dnsServer = lib.mkOption {
      type = lib.types.str;
      default = lan.gateway;
      description = "The container's only DNS server; the one LAN address the namespace may reach, on port 53.";
    };
    vpn = {
      credentialsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "OpenVPN config fragment with inline <ca>, <cert>, <key> and <tls-auth> blocks. The tunnel is off while this is null.";
      };
      remote = lib.mkOption {
        type = lib.types.str;
        # The office server, as in modules/nixos/moberg-vpn.nix.
        default = "71.25.106.254 1194";
      };
      routes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "10.1.10.0 255.255.255.0" ];
        description = "The only routes over the tunnel, as OpenVPN `route` arguments.";
      };
    };
  };

  config = lib.mkMerge [
    # The VM test has no agenix and passes its own files.
    (lib.optionalAttrs (options ? age) {
      age.secrets.executor-env.file = ../../secrets/tleilax/executor-env.age;
      age.secrets.executor-vpn = lib.mkIf (builtins.pathExists vpnSecret) { file = vpnSecret; };
      dotfiles.executor = {
        environmentFile = lib.mkDefault config.age.secrets.executor-env.path;
        vpn.credentialsFile = lib.mkDefault (
          if builtins.pathExists vpnSecret then config.age.secrets.executor-vpn.path else null
        );
      };
    })

    {
      selfhost.tailnetServices.executor = {
        port = servePort;
        bindsTo = "podman-executor.service";
      };

      virtualisation.oci-containers = {
        # Podman can join a named network namespace; Docker can't.
        backend = "podman";
        containers.executor = {
          # digest-pinned; bump with bin/image-pins or the update-image-pins skill
          image = "ghcr.io/usefulsoftwareco/executor-selfhost:v1.6.11@sha256:ea8b4d1019cc00c81cb4236d8edc07a12ac75ef465593b89ae652c0800cd33c1";
          networks = [ "ns:${netnsPath}" ];
          volumes = [ "${dataDir}:/data" ];
          environment = {
            # The image listens on 0.0.0.0, which would include the tunnel.
            EXECUTOR_HOST = "127.0.0.1";
            EXECUTOR_WEB_BASE_URL = "https://executor.sole-pierce.ts.net";
            EXECUTOR_DISABLE_ANALYTICS = "1";
            # Also refuses 10.0.0.0/8, so the office's 10.1.10.x hosts too.
            # In this namespace "local" can only mean Executor's own
            # loopback and the office subnet.
            EXECUTOR_ALLOW_LOCAL_NETWORK = "false";
          };
          # Secrets pass by name from the unit's EnvironmentFile; podman's
          # --env-file would keep any quotes as part of the value.
          extraOptions = [
            "--dns=${cfg.dnsServer}"
          ]
          ++ lib.concatMap (name: [
            "--env"
            name
          ]) requiredEnv;
        };
      };

      systemd.services.podman-executor = {
        requires = [ "executor-netns.service" ];
        after = [ "executor-netns.service" ];
        unitConfig.ConditionPathExists = [
          "|${dataDir}/data.db"
          "|${firstStart}"
        ];
        serviceConfig = {
          EnvironmentFile = cfg.environmentFile;
          ExecStartPre = lib.mkBefore [ preStart ];
        };
      };

      # The image runs as distroless nonroot (65532:65532). Check its User on bumps.
      systemd.tmpfiles.rules = [ "d ${dataDir} 0700 65532 65532 -" ];

      systemd.services.executor-netns = {
        description = "Network namespace for Executor";
        wantedBy = [ "multi-user.target" ];
        path = [
          pkgs.iproute2
          pkgs.nftables
          pkgs.procps
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          ip netns delete ${netns} 2>/dev/null || true
          ip link delete ${hostVeth} 2>/dev/null || true
          ip netns add ${netns}
          ip netns exec ${netns} sysctl -q -w net.ipv6.conf.all.disable_ipv6=1 net.ipv6.conf.default.disable_ipv6=1
          ip netns exec ${netns} nft -f ${netnsRules}
          ip -n ${netns} link set lo up
          ip link add ${hostVeth} type veth peer name ${nsVeth} netns ${netns}
          ip addr add ${hostAddress}/30 dev ${hostVeth}
          ip link set ${hostVeth} up
          ip -n ${netns} addr add ${nsAddress}/30 dev ${nsVeth}
          ip -n ${netns} link set ${nsVeth} up
          ip -n ${netns} route add default via ${hostAddress}
        '';
        preStop = ''
          ip netns delete ${netns} || true
          ip link delete ${hostVeth} 2>/dev/null || true
        '';
      };

      # The host forwards for the namespace only: to the internet, and DNS to
      # the router. Everything else tleilax might route is dropped.
      boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = true;
      systemd.network.config.networkConfig.IPv4Forwarding = true;
      networking.nftables.tables.executor-netns = {
        family = "ip";
        content = ''
          chain forward {
            type filter hook forward priority filter; policy drop;
            ct state established,related accept
            iifname "${hostVeth}" ip daddr ${cfg.dnsServer} meta l4proto { tcp, udp } th dport 53 accept
            iifname "${hostVeth}" oifname "tailscale0" drop
            iifname "${hostVeth}" ip daddr { ${notInternet} } drop
            iifname "${hostVeth}" accept
          }

          chain postrouting {
            type nat hook postrouting priority srcnat; policy accept;
            ip saddr ${nsAddress} oifname != "${hostVeth}" masquerade
          }
        '';
      };

      systemd.sockets.executor-proxy = {
        description = "Tailscale Serve's way into Executor's network namespace";
        wantedBy = [ "sockets.target" ];
        listenStreams = [ "127.0.0.1:${toString servePort}" ];
      };
      systemd.services.executor-proxy = {
        description = "Forward Tailscale Serve's connections into Executor's network namespace";
        requires = [ "executor-netns.service" ];
        after = [ "executor-netns.service" ];
        serviceConfig = {
          ExecStart = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd 127.0.0.1:${toString backendPort}";
          NetworkNamespacePath = netnsPath;
          DynamicUser = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          NoNewPrivileges = true;
          CapabilityBoundingSet = [ "" ];
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_UNIX"
          ];
        };
      };
    }

    (lib.mkIf (cfg.vpn.credentialsFile != null) {
      services.openvpn.servers.executor-vpn = {
        autoStart = true;
        updateResolvConf = false;
        config = ''
          client
          dev tun
          proto udp
          remote ${cfg.vpn.remote}
          nobind
          resolv-retry infinite
          remote-cert-tls server
          auth SHA1
          key-direction 1
          verb 3
          # Take the address the server assigns, but none of its routes, its
          # default gateway or its DNS servers. The namespace has no IPv6.
          route-nopull
          pull-filter ignore "ifconfig-ipv6"
          pull-filter ignore "route-ipv6"
          ${lib.concatMapStrings (route: "route ${route}\n") cfg.vpn.routes}
          config ${cfg.vpn.credentialsFile}
        '';
      };

      systemd.services.openvpn-executor-vpn = {
        requires = [ "executor-netns.service" ];
        after = [ "executor-netns.service" ];
        serviceConfig = {
          NetworkNamespacePath = netnsPath;
          RestartSec = "30s";
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          NoNewPrivileges = true;
          CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
        };
      };
    })
  ];
}
