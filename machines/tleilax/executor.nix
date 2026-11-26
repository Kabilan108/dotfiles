{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.tleilax.executor;
  port = 8304;
  keysFile = ../../secrets/executor/tleilax-v2-keys.env.age;
  id = toString cfg.uid;
  localPorts = lib.attrValues cfg.localServices;
  vpn = config.tleilax.mobergVpn;
  officePorts = lib.unique (
    map (
      origin:
      let
        explicit = builtins.match "https://[^/]+:([0-9]+)" origin;
      in
      if explicit == null then 443 else lib.toInt (builtins.head explicit)
    ) cfg.officeServices
  );
  preferIPv4 = pkgs.writeText "executor-v2-gai.conf" ''
    precedence ::ffff:0:0/96 100
  '';
in
{
  options.tleilax.executor = {
    uid = lib.mkOption {
      type = lib.types.int;
      default = 940;
      description = "Host UID and GID Executor v2 runs as. The `executor-v2` nftables table matches its traffic by this UID.";
    };

    localServices = lib.mkOption {
      type = lib.types.attrsOf lib.types.port;
      default = { };
      example = {
        atlas = 8303;
      };
      description = ''
        Services on this host's loopback that Executor v2 apps may call, by
        name. Each port becomes an allowed `http://127.0.0.1:<port>` origin
        (EXECUTOR_URL_ALLOW_HTTP_ORIGINS) and one of the only loopback ports,
        besides DNS and Executor's own, that the `executor-v2` nftables table
        lets Executor's UID reach. Executor reaches nothing else on loopback,
        the tailnet, the home LAN (router included) or over IPv6.
      '';
    };

    officeServices = lib.mkOption {
      type = lib.types.listOf (lib.types.strMatching "https://[a-z0-9.-]+(:[0-9]+)?");
      default = [ ];
      example = [ "https://pipelines.office.bedsideinfo.org" ];
      description = ''
        HTTPS origins on the Moberg office network that Executor v2 apps may
        call, through the VPN in moberg-vpn.nix. Each is an allowed origin
        (EXECUTOR_URL_ALLOW_HTTP_ORIGINS), the only way Executor connects to
        a name that resolves to a private address, and its port is one the
        `executor-v2` nftables table lets Executor's UID reach on the office
        subnet, through the tunnel only.
      '';
    };
  };

  config = {
    assertions = [
      {
        assertion = builtins.pathExists keysFile;
        message = "Create secrets/executor/tleilax-v2-keys.env.age on jacurutu before deploying Executor v2 (docs/tleilax-install.md).";
      }
    ];

    age.secrets.executor-v2-keys = {
      file = keysFile;
      mode = "0400";
    };

    users.users.executor-v2 = {
      isSystemUser = true;
      inherit (cfg) uid;
      group = "executor-v2";
    };
    users.groups.executor-v2.gid = cfg.uid;

    virtualisation.podman.enable = true;
    virtualisation.oci-containers.backend = "podman";

    selfhost.tailnetServices.executor-v2.port = port;

    virtualisation.oci-containers.containers.executor-v2 = {
      image = "ghcr.io/usefulsoftwareco/executor-selfhost:2.0.0-beta.74@sha256:054e677a1f694ffa827a82d0cb501dbd087c9e576b64b3473c91ca874f92c44a";
      user = "${id}:${id}";
      volumes = [
        "/var/lib/executor-v2:/app/data"
        "/var/cache/executor-v2-telemetry:/app/motel-data"
        "${preferIPv4}:/etc/gai.conf:ro"
      ];
      environmentFiles = [ config.age.secrets.executor-v2-keys.path ];
      environment = {
        HOST = "127.0.0.1";
        PORT = toString port;
        BETTER_AUTH_URL = "https://executor-v2.sole-pierce.ts.net";
        EXECUTOR_DISABLE_ANALYTICS = "1";
        EXECUTOR_NO_UPDATE_CHECK = "1";
        EXECUTOR_APPS_ALLOW_PRIVATE_FETCH = lib.boolToString (
          cfg.localServices != { } || cfg.officeServices != [ ]
        );
        EXECUTOR_URL_ALLOW_HTTP_ORIGINS = builtins.toJSON (
          map (p: "http://127.0.0.1:${toString p}") localPorts ++ cfg.officeServices
        );
        EXECUTOR_APP_WORKERS = "16";
      };
      extraOptions = [
        "--network=host"
        "--init"
        "--stop-timeout=30"
      ];
    };

    networking.nftables.tables.executor-v2 = {
      family = "inet";
      content = ''
        chain output {
          type filter hook output priority -10; policy accept;

          meta skuid ${id} jump executor
        }

        chain executor {
          ct state established,related accept

          oifname "lo" ip daddr 127.0.0.53 meta l4proto { tcp, udp } th dport 53 accept
          oifname "lo" ip daddr 127.0.0.1 tcp dport { ${
            lib.concatMapStringsSep ", " toString ([ port ] ++ localPorts)
          } } accept
          ${lib.optionalString (officePorts != [ ]) ''
            oifname "${vpn.interface}" ip daddr ${vpn.subnet} tcp dport { ${
              lib.concatMapStringsSep ", " toString officePorts
            } } accept
          ''}
          meta nfproto ipv6 reject with icmpx admin-prohibited
          oifname { "lo", "tailscale0" } drop
          ip daddr { 10.0.0.0/8, 100.64.0.0/10, 169.254.0.0/16, 172.16.0.0/12, 192.168.0.0/16 } drop
        }
      '';
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/executor-v2 0700 ${id} ${id} -"
      "Z /var/lib/executor-v2 - ${id} ${id} -"
      "d /var/cache/executor-v2-telemetry 0700 ${id} ${id} -"
    ];
  };
}
