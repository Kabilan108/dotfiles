{
  config,
  lib,
  pkgs,
  ...
}:
let
  relays = import ./mullvad-relays.nix;
  cfg = config.selfhost.mediaArr;
  relay = relays.${cfg.mullvadServer};

  frontPort = 8330;
  prowlarrPort = 8331;
  radarrPort = 8332;
  sonarrPort = 8333;
  qbitPort = 8334;

  downloadsDir = "/vault/userdata/downloads";
  keyFile = ../../../secrets/selfhost/torrent-wg-key.age;
  netnsName = "torrent";
  wgInterface = "wg-torrent";
  mullvadDns = "10.64.0.1";
  netnsResolv = "/etc/netns/${netnsName}/resolv.conf";
  qbitConf = "/var/lib/qBittorrent/qBittorrent/config/qBittorrent.conf";

  torrentNetnsUp = pkgs.writeShellApplication {
    name = "torrent-netns-up";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.iproute2
      pkgs.nftables
      pkgs.wireguard-tools
    ];
    text = ''
      key_file="$1"
      endpoint="$2"
      peer_pubkey="$3"
      netns=${lib.escapeShellArg netnsName}
      iface=${lib.escapeShellArg wgInterface}
      dns=${lib.escapeShellArg mullvadDns}

      private_key=""
      addresses=""
      tmp_key=""

      cleanup() {
        rc=$?
        rm -f "$tmp_key"
        if ((rc != 0)); then
          ip netns del "$netns" 2>/dev/null || true
          ip link del "$iface" 2>/dev/null || true
        fi
      }
      trap cleanup EXIT

      while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
        line="''${raw_line%%$'\r'}"
        case "$line" in
          "" | \[* | \#*) continue ;;
        esac
        key="''${line%%=*}"
        val="''${line#*=}"
        key="''${key//[[:space:]]/}"
        val="''${val#"''${val%%[![:space:]]*}"}"
        val="''${val%"''${val##*[![:space:]]}"}"
        case "$key" in
          PrivateKey | PRIVATE_KEY) private_key="$val" ;;
          Address | ADDRESS) addresses="$val" ;;
        esac
      done < "$key_file"

      if [[ -z "$private_key" || -z "$addresses" ]]; then
        echo "torrent-netns-up: missing PrivateKey or Address in $key_file" >&2
        exit 1
      fi

      ip netns del "$netns" 2>/dev/null || true
      ip link del "$iface" 2>/dev/null || true

      mkdir -p "/etc/netns/$netns"
      printf 'nameserver %s\n' "$dns" > "/etc/netns/$netns/resolv.conf"
      chmod 0644 "/etc/netns/$netns/resolv.conf"

      ip netns add "$netns"
      ip link add "$iface" type wireguard

      tmp_key="$(mktemp)"
      chmod 0600 "$tmp_key"
      printf '%s\n' "$private_key" > "$tmp_key"

      wg set "$iface" \
        private-key "$tmp_key" \
        peer "$peer_pubkey" \
        endpoint "$endpoint" \
        allowed-ips "0.0.0.0/0,::/0" \
        persistent-keepalive 25

      rm -f "$tmp_key"
      tmp_key=""

      ip link set "$iface" netns "$netns"
      ip -n "$netns" link set lo up

      has_v6=0
      IFS=',' read -r -a addr_list <<< "$addresses"
      for raw_addr in "''${addr_list[@]}"; do
        addr="''${raw_addr//[[:space:]]/}"
        [[ -n "$addr" ]] || continue
        ip -n "$netns" addr add "$addr" dev "$iface"
        if [[ "$addr" == *:* ]]; then
          has_v6=1
        fi
      done

      ip -n "$netns" link set "$iface" mtu 1420 up
      ip -n "$netns" route replace default dev "$iface"
      if ((has_v6)); then
        ip -n "$netns" -6 route replace default dev "$iface"
      fi

      ip netns exec "$netns" nft -f - <<'EOF'
      table inet torrent {
        chain input {
          type filter hook input priority 0; policy drop;
          iifname "lo" accept
          ct state established,related accept
        }
        chain forward {
          type filter hook forward priority 0; policy drop;
        }
        chain output {
          type filter hook output priority 0; policy drop;
          oifname "lo" accept
          oifname "wg-torrent" accept
        }
      }
      EOF
    '';
  };

  torrentNetnsDown = pkgs.writeShellApplication {
    name = "torrent-netns-down";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.iproute2
    ];
    text = ''
      ip netns del ${lib.escapeShellArg netnsName} 2>/dev/null || true
      ip link del ${lib.escapeShellArg wgInterface} 2>/dev/null || true
      rm -f ${lib.escapeShellArg netnsResolv}
    '';
  };

  initialQbitConf = pkgs.writeText "qBittorrent-initial.conf" ''
    [BitTorrent]
    Session\DefaultSavePath=${downloadsDir}/complete
    Session\ExcludedFileNames="*.exe\n*.bat\n*.cmd\n*.com\n*.msi\n*.scr\n*.pif\n*.lnk\n*.vbs\n*.js\n*.jse\n*.ps1\n*.sh\n*.iso\n*.img\n*.zip\n*.rar\n*.7z\n*.tar\n*.gz"
    Session\ExcludedFileNamesEnabled=true
    Session\GlobalMaxRatio=0
    Session\GlobalMaxSeedingMinutes=0
    Session\Interface=${wgInterface}
    Session\InterfaceName=${wgInterface}
    Session\ShareLimitAction=Stop
    Session\TempPath=${downloadsDir}/incomplete
    Session\TempPathEnabled=true

    [LegalNotice]
    Accepted=true

    [Preferences]
    WebUI\Address=127.0.0.1
    WebUI\Port=${toString qbitPort}
    WebUI\ReverseProxySupportEnabled=true
    WebUI\ServerDomains=arr.sole-pierce.ts.net
    WebUI\TrustedReverseProxiesList=127.0.0.1
  '';

  arrLanding = pkgs.writeTextDir "index.html" ''
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>arr</title>
        <style>
          body { font-family: system-ui, sans-serif; background: #111318; color: #e5e7eb; margin: 2rem; }
          ul { list-style: none; padding: 0; display: grid; gap: 0.75rem; max-width: 18rem; }
          a { display: block; padding: 0.75rem 1rem; background: #1c202a; color: #93c5fd; text-decoration: none; border-radius: 0.5rem; }
          a:hover { background: #262c3a; }
        </style>
      </head>
      <body>
        <h1>arr</h1>
        <ul>
          <li><a href="/prowlarr/">Prowlarr</a></li>
          <li><a href="/radarr/">Radarr</a></li>
          <li><a href="/sonarr/">Sonarr</a></li>
          <li><a href="/qbit/">qBittorrent</a></li>
        </ul>
      </body>
    </html>
  '';

  arrProxyHeaders = ''
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Proto https;
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_redirect off;
  '';
in
{
  options.selfhost.mediaArr = {
    mullvadServer = lib.mkOption {
      type = lib.types.enum (lib.attrNames relays);
      default = "us-nyc-wg-301";
      description = "Mullvad New York WireGuard relay used by the torrent network namespace.";
    };
  };

  config = {
    assertions = [
      {
        assertion = builtins.pathExists keyFile;
        message = "Create secrets/selfhost/torrent-wg-key.age on jacurutu before deploying sietch.";
      }
    ];

    age.secrets.selfhost-torrent-wg-key = {
      file = keyFile;
      mode = "0400";
    };

    selfhost.tailnetServices.arr.port = frontPort;

    users.groups.media-dl = { };

    users.users.radarr.extraGroups = [
      "media-dl"
      "users"
    ];
    users.users.sonarr.extraGroups = [
      "media-dl"
      "users"
    ];

    systemd.tmpfiles.rules = [
      "d ${downloadsDir} 2775 qbittorrent media-dl -"
      "d ${downloadsDir}/incomplete 2775 qbittorrent media-dl -"
      "d ${downloadsDir}/complete 2775 qbittorrent media-dl -"
    ];

    systemd.tmpfiles.settings.qbittorrent = {
      "/var/lib/qBittorrent/qBittorrent/".d.mode = lib.mkForce "0700";
      "/var/lib/qBittorrent/qBittorrent/config/".d.mode = lib.mkForce "0700";
    };

    systemd.services.torrent-netns = {
      description = "Isolated Mullvad WireGuard network namespace for torrent traffic";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [
        relay.ipv4
        relay.pubkey
        config.age.secrets.selfhost-torrent-wg-key.file
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${lib.getExe torrentNetnsUp} ${config.age.secrets.selfhost-torrent-wg-key.path} ${relay.ipv4}:51820 ${relay.pubkey}";
        ExecStop = lib.getExe torrentNetnsDown;
      };
    };

    services.qbittorrent = {
      enable = true;
      group = "media-dl";
      webuiPort = qbitPort;
      extraArgs = [ "--confirm-legal-notice" ];
    };

    systemd.services.qbittorrent = {
      bindsTo = [ "torrent-netns.service" ];
      partOf = [ "torrent-netns.service" ];
      requires = [ "torrent-netns.service" ];
      after = [ "torrent-netns.service" ];
      preStart = ''
        if [[ ! -e ${lib.escapeShellArg qbitConf} ]]; then
          ${pkgs.coreutils}/bin/install -Dm600 ${initialQbitConf} ${lib.escapeShellArg qbitConf}
        fi
      '';
      serviceConfig = {
        NetworkNamespacePath = "/var/run/netns/${netnsName}";
        BindReadOnlyPaths = [ "${netnsResolv}:/etc/resolv.conf" ];
        InaccessiblePaths = [
          "-/run/nscd"
          "-/run/systemd/resolve"
        ];
        UMask = "0007";
      };
    };

    systemd.sockets.qbittorrent-webui-proxy = {
      description = "Loopback socket bridge for qBittorrent Web UI";
      wantedBy = [ "sockets.target" ];
      listenStreams = [ "127.0.0.1:${toString qbitPort}" ];
    };

    systemd.services.qbittorrent-webui-proxy = {
      description = "Socket proxy into the torrent network namespace for qBittorrent Web UI";
      bindsTo = [ "torrent-netns.service" ];
      requires = [
        "qbittorrent.service"
        "qbittorrent-webui-proxy.socket"
        "torrent-netns.service"
      ];
      after = [
        "qbittorrent.service"
        "qbittorrent-webui-proxy.socket"
        "torrent-netns.service"
      ];
      serviceConfig = {
        ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd --exit-idle-time=5m 127.0.0.1:${toString qbitPort}";
        NetworkNamespacePath = "/var/run/netns/${netnsName}";
        DynamicUser = true;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
      };
    };

    services.prowlarr = {
      enable = true;
      settings = {
        auth = {
          method = "Forms";
          required = "Enabled";
        };
        server = {
          bindaddress = "127.0.0.1";
          port = prowlarrPort;
          urlbase = "/prowlarr";
        };
      };
    };

    services.radarr = {
      enable = true;
      settings = {
        auth = {
          method = "Forms";
          required = "Enabled";
        };
        server = {
          bindaddress = "127.0.0.1";
          port = radarrPort;
          urlbase = "/radarr";
        };
      };
    };

    services.sonarr = {
      enable = true;
      settings = {
        auth = {
          method = "Forms";
          required = "Enabled";
        };
        server = {
          bindaddress = "127.0.0.1";
          port = sonarrPort;
          urlbase = "/sonarr";
        };
      };
    };

    services.nginx = {
      enable = true;
      virtualHosts.media-arr = {
        listen = [
          {
            addr = "127.0.0.1";
            port = frontPort;
          }
        ];
        serverName = "_";
        extraConfig = ''
          access_log off;
          absolute_redirect off;
        '';
        locations = {
          "/" = {
            return = "404";
          };
          "= /" = {
            root = arrLanding;
            extraConfig = "try_files /index.html =404;";
          };
          "= /prowlarr".return = "302 /prowlarr/";
          "^~ /prowlarr/" = {
            proxyPass = "http://127.0.0.1:${toString prowlarrPort}";
            proxyWebsockets = true;
            extraConfig = arrProxyHeaders;
          };
          "= /radarr".return = "302 /radarr/";
          "^~ /radarr/" = {
            proxyPass = "http://127.0.0.1:${toString radarrPort}";
            proxyWebsockets = true;
            extraConfig = arrProxyHeaders;
          };
          "= /sonarr".return = "302 /sonarr/";
          "^~ /sonarr/" = {
            proxyPass = "http://127.0.0.1:${toString sonarrPort}";
            proxyWebsockets = true;
            extraConfig = arrProxyHeaders;
          };
          "= /qbit".return = "302 /qbit/";
          "^~ /qbit/" = {
            proxyPass = "http://127.0.0.1:${toString qbitPort}/";
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Forwarded-Host $host;
              proxy_set_header X-Forwarded-Proto https;
              proxy_set_header X-Forwarded-For $remote_addr;
              proxy_cookie_path / "/qbit/; Secure";
              proxy_redirect off;
            '';
          };
        };
      };
    };
  };
}
