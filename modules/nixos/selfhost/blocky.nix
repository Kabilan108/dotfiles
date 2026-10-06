{
  config,
  lib,
  pkgs,
  ...
}:
let
  fleet = import ../../../lib/fleet.nix;
  tailscaleIp = fleet.hosts.${config.networking.hostName}.tailscaleIp;
in
{
  age.secrets.selfhost-blocky-denylist.file = ../../../secrets/selfhost/blocky-denylist.age;

  # Publish only DoH, not Blocky's management API or memory profiler.
  selfhost.tailnetServices.blocky.port = 8319;

  services.blocky = {
    enable = true;
    # Blocky's normal HTTP listener exposes unauthenticated management and
    # profiling routes even on loopback. Keep DoH while removing both routers.
    package = pkgs.blocky.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace server/server_endpoints.go \
          --replace-fail 'api.RegisterOpenAPIEndpoints(router, openAPIImpl)' "" \
          --replace-fail 'configureDebugHandler(router)' ""
      '';
    });
    settings = {
      ports = {
        # Standard DNS uses the node IP; Tailscale Services proxies DoH.
        dns = "${tailscaleIp}:53";
        http = "127.0.0.1:8318";
      };
      # IP literals avoid depending on the DNS service we are providing.
      upstreams.groups.default = [
        "https://1.1.1.1/dns-query"
        "https://1.0.0.1/dns-query"
      ];
      # Resolve blocklist hosts without the system resolver, which may use Blocky.
      bootstrapDns = [
        "https://1.1.1.1/dns-query"
        "https://1.0.0.1/dns-query"
      ];
      conditional.mapping.${fleet.tailnet} = "100.100.100.100";
      log = {
        privacy = true;
        level = "warn";
      };
      queryLog.type = "none";
      statistics.enable = false;
      prometheus.enable = false;
      caching = {
        maxTime = "-1s";
        cacheTimeNegative = "-1s";
        prefetching = false;
      };
      blocking = {
        denylists = {
          ads = [ "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" ];
          private = [ "/run/credentials/blocky.service/denylist" ];
        };
        clientGroupsBlock.default = [
          "ads"
          "private"
        ];
        loading = {
          strategy = "failOnError";
          refreshPeriod = "24h";
          downloads.timeout = "60s";
        };
      };
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts.blocky-doh = {
      listen = [
        {
          addr = "127.0.0.1";
          port = 8319;
        }
      ];
      serverName = "_";
      default = true;
      extraConfig = ''
        access_log off;
        error_log /dev/null;
      '';
      locations."/".return = "404";
      locations."= /dns-query" = {
        proxyPass = "http://127.0.0.1:8318";
        extraConfig = ''
          proxy_cache off;
          proxy_buffering off;
          proxy_request_buffering off;
          proxy_max_temp_file_size 0;
          client_max_body_size 1k;
        '';
      };
    };
  };

  networking.firewall.interfaces.tailscale0 = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 ];
  };

  systemd.services.blocky = {
    restartTriggers = [ config.age.secrets.selfhost-blocky-denylist.file ];
    # Blocky serves remote clients, not the host's early-boot resolver.
    # Remove the native module's nss-lookup ordering before waiting for Tailscale.
    before = lib.mkForce [ ];
    wants = lib.mkForce [
      "network-online.target"
      "tailscaled.service"
    ];
    after = [
      "network-online.target"
      "tailscaled.service"
    ];
    # tailscaled may be running before its address is assigned.
    startLimitIntervalSec = 0;
    serviceConfig = {
      RestartSec = "5s";
      LoadCredential = [ "denylist:${config.age.secrets.selfhost-blocky-denylist.path}" ];
      # Privacy redaction preserves name lengths and is not applied to every error.
      # Discard application output rather than retain a partial activity record.
      StandardOutput = "null";
      StandardError = "null";
      LimitCORE = 0;
      MemorySwapMax = 0;
    };
  };

  systemd.services.nginx.serviceConfig = {
    LimitCORE = 0;
    MemorySwapMax = 0;
  };

  # Tailscale Serve handles decrypted DoH messages before the localhost proxy.
  systemd.services.tailscaled.serviceConfig = {
    LimitCORE = 0;
    MemorySwapMax = 0;
  };
}
