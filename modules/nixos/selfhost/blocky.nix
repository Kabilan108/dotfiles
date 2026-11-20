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

  selfhost.tailnetServices.blocky.port = 8319;

  services.blocky = {
    enable = true;
    package = pkgs.blocky.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace server/server_endpoints.go \
          --replace-fail 'api.RegisterOpenAPIEndpoints(router, openAPIImpl)' "" \
          --replace-fail 'configureDebugHandler(router)' ""
      '';
    });
    settings = {
      ports = {
        dns = "${tailscaleIp}:53";
        http = "127.0.0.1:8318";
      };
      upstreams.groups.default = [
        "https://1.1.1.1/dns-query"
        "https://1.0.0.1/dns-query"
      ];
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
    before = lib.mkForce [ ];
    wants = lib.mkForce [
      "network-online.target"
      "tailscaled.service"
    ];
    after = [
      "network-online.target"
      "tailscaled.service"
    ];
    startLimitIntervalSec = 120;
    startLimitBurst = 5;
    path = [
      pkgs.iproute2
      pkgs.jq
    ];
    preStart = ''
      until ip -j -4 address show dev ${lib.escapeShellArg config.services.tailscale.interfaceName} \
        | jq -e --arg ip ${lib.escapeShellArg tailscaleIp} 'any(.[].addr_info[]; .local == $ip)' >/dev/null 2>&1; do
        sleep 1
      done
    '';
    serviceConfig = {
      RestartSec = "5s";
      TimeoutStartSec = "infinity";
      RestrictAddressFamilies = [ "AF_NETLINK" ];
      LoadCredential = [ "denylist:${config.age.secrets.selfhost-blocky-denylist.path}" ];
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

  systemd.services.tailscaled.serviceConfig = {
    LimitCORE = 0;
    MemorySwapMax = 0;
  };
}
