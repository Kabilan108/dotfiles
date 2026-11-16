# Executor v2 (beta), reachable as executor-v2.sole-pierce.ts.net. It starts
# empty; nothing migrates from v1 on sietch.
#
# BETTER_AUTH_SECRET and EXECUTOR_ENCRYPTION_KEY come from agenix, so the
# data volume never holds the key that decrypts its credentials. Executor
# refuses to start if the key source changes under an existing database, so
# the secret must exist before the first boot: create it on jacurutu as in
# docs/tleilax-install.md ("Executor v2 keys").
{ config, lib, ... }:
let
  cfg = config.tleilax.executor;
  port = 8304;
  keysFile = ../../secrets/executor/tleilax-v2-keys.env.age;
  id = toString cfg.uid;
  localPorts = lib.attrValues cfg.localServices;
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

    # Podman: no daemon to keep running on the Pi.
    virtualisation.podman.enable = true;
    virtualisation.oci-containers.backend = "podman";

    selfhost.tailnetServices.executor-v2.port = port;

    virtualisation.oci-containers.containers.executor-v2 = {
      # Bump by tag (each beta is a new tag), then re-pin the digest.
      image = "ghcr.io/usefulsoftwareco/executor-selfhost:2.0.0-beta.54@sha256:4a6cdf338ad62ec85a08986518f60cc9dc1d3f81a1468b1f7d7ecef6ca20d16b";
      user = "${id}:${id}";
      volumes = [
        "/var/lib/executor-v2:/app/data"
        "/var/cache/executor-v2-telemetry:/app/motel-data"
      ];
      environmentFiles = [ config.age.secrets.executor-v2-keys.path ];
      environment = {
        HOST = "127.0.0.1";
        PORT = toString port;
        BETTER_AUTH_URL = "https://executor-v2.sole-pierce.ts.net";
        EXECUTOR_DISABLE_ANALYTICS = "1";
        EXECUTOR_APPS_ALLOW_PRIVATE_FETCH = lib.boolToString (cfg.localServices != { });
        EXECUTOR_URL_ALLOW_HTTP_ORIGINS = builtins.toJSON (
          map (p: "http://127.0.0.1:${toString p}") localPorts
        );
        EXECUTOR_APP_WORKERS = "16";
      };
      extraOptions = [
        "--network=host"
        "--init"
      ];
    };

    networking.nftables.tables.executor-v2 = {
      family = "inet";
      content = ''
        chain output {
          type filter hook output priority -10; policy accept;

          meta skuid != ${id} accept
          ct state established,related accept

          oifname "lo" ip daddr 127.0.0.53 meta l4proto { tcp, udp } th dport 53 accept
          oifname "lo" ip daddr 127.0.0.1 tcp dport { ${
            lib.concatMapStringsSep ", " toString ([ port ] ++ localPorts)
          } } accept

          oifname { "lo", "tailscale0" } drop
          meta nfproto ipv6 drop
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
