# VM test for tleilax's credential services (machines/tleilax/services.nix),
# with a stub HTTP server in place of the Executor image, a stand-in for the
# tailscale CLI, and a real OpenVPN server for the office. From the repo root:
#   nix build --impure --expr 'import ./tests/tleilax-credentials.nix { pkgs = (builtins.getFlake "git+file://${toString ./.}").inputs.nixpkgs.legacyPackages.x86_64-linux; }'
#
# Addresses follow the real ones: the LAN is 10.0.0.0/24 behind a router at
# 10.0.0.1 that also serves DNS, the office server is on the "internet"
# (203.0.113.0/24), and the office subnet is 10.1.10.0/24. The router answers
# on 100.100.100.100 as a stand-in for the tailnet.
{ pkgs }:
let
  inherit (pkgs) lib;

  # Scripted networking ignores extra addresses on lo.
  loAddresses = addresses: {
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.iproute2 ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = lib.concatMapStrings (address: "ip addr add ${address} dev lo\n") addresses;
  };

  webServer = body: {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.ExecStart = "${pkgs.python3}/bin/python3 -m http.server 80 --bind 0.0.0.0 --directory ${pkgs.writeTextDir "index.html" body}";
  };

  vpnCerts =
    pkgs.runCommand "test-vpn-certs"
      {
        nativeBuildInputs = [
          pkgs.openssl
          pkgs.openvpn
        ];
      }
      ''
        mkdir "$out" && cd "$out"
        ec="-newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes"
        openssl req -x509 $ec -subj /CN=test-ca -days 3650 -keyout ca.key -out ca.crt
        printf 'basicConstraints=CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth\n' > server.ext
        printf 'basicConstraints=CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=clientAuth\n' > client.ext
        for role in server client; do
          openssl req $ec -subj /CN=$role -keyout $role.key -out $role.csr
          openssl x509 -req -in $role.csr -CA ca.crt -CAkey ca.key -CAcreateserial -days 3650 \
            -extfile $role.ext -out $role.crt
        done
        openvpn --genkey secret ta.key
        {
          echo "<ca>"; cat ca.crt; echo "</ca>"
          echo "<cert>"; cat client.crt; echo "</cert>"
          echo "<key>"; cat client.key; echo "</key>"
          echo "<tls-auth>"; cat ta.key; echo "</tls-auth>"
        } > client-credentials.conf
      '';

  adminTokenHash =
    pkgs.runCommand "test-admin-token-hash" { nativeBuildInputs = [ pkgs.libargon2 ]; }
      ''
        printf %s test-admin-token | argon2 test-salt-16bytes -id -e > "$out"
      '';

  # Records serve configuration as files under /var/lib/fake-tailscale, the
  # way tailscaled keeps it across restarts.
  fakeTailscale = pkgs.writeShellScriptBin "tailscale" ''
    set -eu
    state=/var/lib/fake-tailscale
    echo "$*" >> /var/log/fake-tailscale.log
    case "$1 ''${2-}" in
      "status --json") echo '{"BackendState":"Running"}' ;;
      "serve status")
        # shellcheck disable=SC2046
        ${pkgs.jq}/bin/jq -n '{Services: ($ARGS.positional | map({key: ., value: {}}) | from_entries)}' \
          --args $(ls "$state") ;;
      "serve clear") rm -f "$state/$3" ;;
      "serve --service="*) touch "$state/''${2#--service=}" ;;
      *) echo "fake tailscale: unexpected arguments: $*" >&2; exit 1 ;;
    esac
  '';

  stubStart = pkgs.writeScriptBin "stub-start" ''
    #!/bin/sh
    set -eu
    touch /data/data.db
    mkdir -p /data/www
    {
      echo executor-stub
      echo "secret-key-length ''${#EXECUTOR_SECRET_KEY}"
      echo "admin-email $EXECUTOR_BOOTSTRAP_ADMIN_EMAIL"
    } > /data/www/index.html
    exec httpd -f -p "$EXECUTOR_HOST:$PORT" -h /data/www
  '';

  # Same user, port and listen variable as the real image.
  stubImage = pkgs.dockerTools.buildImage {
    name = "executor-stub";
    tag = "test";
    copyToRoot = pkgs.buildEnv {
      name = "executor-stub-root";
      paths = [
        pkgs.busybox
        stubStart
      ];
      pathsToLink = [ "/bin" ];
    };
    config = {
      User = "65532:65532";
      Env = [
        "PORT=4788"
        "EXECUTOR_HOST=0.0.0.0"
      ];
      Cmd = [ "/bin/stub-start" ];
    };
  };
  # tleilax's own network setup, including its egress filter, with static
  # addresses and without the real tailscaled.
  tleilaxBase = {
    imports = [ ../machines/tleilax/network.nix ];
    networking.useDHCP = false;
    services.tailscale.enable = lib.mkForce false;
  };

  # tleilax's credential services, with stand-ins for the tailscale CLI, the
  # agenix secrets and the Executor image.
  credentials = {
    imports = [ ../machines/tleilax/services.nix ];
    services.tailscale.package = fakeTailscale;
    systemd.services.tailscaled = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig.ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
    };
    systemd.tmpfiles.rules = [ "d /var/lib/fake-tailscale 0755 root root -" ];
    dotfiles.vaultwarden.environmentFile = "/var/lib/test-secrets/vaultwarden.env";
    dotfiles.executor.environmentFile = "/var/lib/test-secrets/executor.env";
    virtualisation.oci-containers.containers.executor = {
      image = lib.mkForce "localhost/executor-stub:test";
      imageFile = stubImage;
    };
  };
in
pkgs.testers.runNixOSTest {
  name = "tleilax-credentials";

  # Switches from the old config to the new one, as tleilax's first deploy
  # of this change does. The VPN credential doesn't exist yet there either.
  nodes.fresh =
    { ... }:
    {
      imports = [ tleilaxBase ];
      virtualisation.memorySize = 1536;
      specialisation.credentials.configuration = credentials;
    };

  nodes.router =
    { ... }:
    {
      virtualisation.vlans = [
        1
        2
      ];
      networking.useDHCP = false;
      networking.firewall.enable = false;
      networking.interfaces.eth1.ipv4.addresses = lib.mkForce [
        {
          address = "10.0.0.1";
          prefixLength = 24;
        }
      ];
      networking.interfaces.eth2.ipv4.addresses = lib.mkForce [
        {
          address = "203.0.113.1";
          prefixLength = 24;
        }
      ];
      systemd.services.lo-addresses = loAddresses [ "100.100.100.100/32" ];
      networking.nat = {
        enable = true;
        internalInterfaces = [ "eth1" ];
        externalInterface = "eth2";
      };
      services.dnsmasq = {
        enable = true;
        resolveLocalQueries = false;
        settings = {
          listen-address = "10.0.0.1";
          bind-interfaces = true;
          no-resolv = true;
          address = "/internet.test/203.0.113.1";
        };
      };
      systemd.services.web = webServer "router";
    };

  nodes.office =
    { ... }:
    {
      virtualisation.vlans = [ 2 ];
      networking.useDHCP = false;
      networking.firewall.enable = false;
      networking.interfaces.eth1.ipv4.addresses = lib.mkForce [
        {
          address = "203.0.113.20";
          prefixLength = 24;
        }
      ];
      # The office subnet, and one the server pushes that the Pi must ignore.
      systemd.services.lo-addresses = loAddresses [
        "10.1.10.5/32"
        "10.9.9.5/32"
      ];
      environment.systemPackages = [ pkgs.curl ];
      services.openvpn.servers.office.config = ''
        dev tun
        proto udp
        port 1194
        topology subnet
        server 10.8.0.0 255.255.255.0
        ca ${vpnCerts}/ca.crt
        cert ${vpnCerts}/server.crt
        key ${vpnCerts}/server.key
        dh none
        tls-auth ${vpnCerts}/ta.key 0
        auth SHA1
        keepalive 5 30
        push "redirect-gateway def1"
        push "route 10.1.10.0 255.255.255.0"
        push "route 10.9.9.0 255.255.255.0"
        push "dhcp-option DNS 10.1.10.53"
      '';
      systemd.services.web = webServer "office";
    };

  nodes.pi =
    { ... }:
    {
      imports = [
        tleilaxBase
        credentials
      ];

      virtualisation.vlans = [ 1 ];
      virtualisation.memorySize = 2048;
      virtualisation.diskSize = 4096;

      networking.interfaces.eth1.ipv4 = {
        addresses = lib.mkForce [
          {
            address = "10.0.0.67";
            prefixLength = 24;
          }
        ];
        routes = [
          {
            address = "100.64.0.0";
            prefixLength = 10;
            via = "10.0.0.1";
          }
        ];
      };
      networking.defaultGateway = {
        address = "10.0.0.1";
        interface = "eth1";
      };

      dotfiles.executor.vpn = {
        credentialsFile = "${vpnCerts}/client-credentials.conf";
        remote = "203.0.113.20 1194";
      };

      # A host service on every address, which the namespace mustn't reach.
      systemd.services.host-only = webServer "host-only" // {
        serviceConfig.ExecStart = "${pkgs.python3}/bin/python3 -m http.server 9999 --bind 0.0.0.0 --directory ${pkgs.writeTextDir "index.html" "host-only"}";
      };

      environment.systemPackages = [ pkgs.curl ];
    };

  testScript = ''
    def advertised(machine=pi):
        return sorted(machine.succeed("ls /var/lib/fake-tailscale").split())

    def unit_state(unit, machine=pi):
        return machine.succeed(f"systemctl show -P ActiveState {unit}").strip()

    def dump(unit):
        print(pi.execute(f"systemctl status --no-pager {unit}; journalctl -b --no-pager -u {unit}")[1])
        print(pi.execute("podman ps -a; ls -la /var/lib/executor")[1])

    def write_executor_env(value, email):
        pi.succeed(
            "printf 'EXECUTOR_SECRET_KEY=%s\\nBETTER_AUTH_SECRET=%s\\n"
            "EXECUTOR_BOOTSTRAP_ADMIN_EMAIL=%s\\nEXECUTOR_BOOTSTRAP_ADMIN_PASSWORD=%s\\n' "
            f"'{value}' '{value}' '{email}' '{value}' > /var/lib/test-secrets/executor.env"
        )

    start_all()
    router.wait_for_unit("dnsmasq.service")
    router.wait_for_unit("web.service")
    router.wait_for_unit("lo-addresses.service")
    office.wait_for_unit("lo-addresses.service")
    office.wait_for_unit("openvpn-office.service")
    office.wait_for_unit("web.service")
    pi.wait_for_unit("multi-user.target")
    pi.succeed("install -d -m 0700 /var/lib/test-secrets")

    with subtest("the first deploy switches cleanly and starts nothing"):
        fresh.wait_for_unit("multi-user.target")
        fresh.succeed("/run/current-system/specialisation/credentials/bin/switch-to-configuration test")
        for unit in ["vaultwarden.service", "podman-executor.service"]:
            assert unit_state(unit, fresh) == "inactive", unit
            assert fresh.succeed(f"systemctl show -P ConditionResult {unit}").strip() == "no", unit
        for unit in ["tailscale-serve-vault.service", "tailscale-serve-executor.service"]:
            assert unit_state(unit, fresh) == "inactive", unit
        fresh.succeed("systemctl is-active executor-netns.service executor-proxy.socket tailscale-serve-config.service")
        fresh.fail("systemctl is-active openvpn-executor-vpn.service")
        failed = fresh.succeed("systemctl list-units --failed --plain --no-legend")
        assert failed.strip() == "", failed
        assert advertised(fresh) == [], advertised(fresh)

    with subtest("without data nothing starts and nothing is advertised"):
        pi.wait_for_unit("executor-netns.service")
        pi.wait_for_unit("tailscale-serve-config.service")
        for unit in ["vaultwarden.service", "podman-executor.service"]:
            assert unit_state(unit) == "inactive", unit
            assert pi.succeed(f"systemctl show -P ConditionResult {unit}").strip() == "no", unit
        assert advertised() == [], advertised()

    with subtest("a zero-byte database doesn't count as copied data"):
        pi.succeed("install -d -o vaultwarden -g vaultwarden -m 0700 /var/lib/vaultwarden")
        pi.succeed("install -o vaultwarden -g vaultwarden -m 0600 /dev/null /var/lib/vaultwarden/db.sqlite3")
        pi.succeed("systemctl start vaultwarden.service")
        assert unit_state("vaultwarden.service") == "inactive", unit_state("vaultwarden.service")
        assert pi.succeed("systemctl show -P ConditionResult vaultwarden.service").strip() == "no"
        assert advertised() == [], advertised()

    with subtest("Vaultwarden refuses a placeholder admin token"):
        pi.succeed("${pkgs.sqlite}/bin/sqlite3 /var/lib/vaultwarden/db.sqlite3 'PRAGMA journal_mode=WAL;'")
        pi.succeed("chown -R vaultwarden:vaultwarden /var/lib/vaultwarden")
        pi.succeed("printf 'ADMIN_TOKEN=REPLACE_ME\\n' > /var/lib/test-secrets/vaultwarden.env")
        pi.fail("systemctl start vaultwarden.service")
        pi.wait_until_succeeds("journalctl -u vaultwarden.service | grep -q 'must be an Argon2id PHC string'")
        assert advertised() == [], advertised()

    with subtest("Vaultwarden starts on copied data and is advertised while it runs"):
        pi.succeed("printf \"ADMIN_TOKEN='%s'\\n\" \"$(cat ${adminTokenHash})\" > /var/lib/test-secrets/vaultwarden.env")
        pi.succeed("systemctl reset-failed vaultwarden.service")
        pi.succeed("systemctl start vaultwarden.service")
        pi.wait_until_succeeds("curl -fsS http://127.0.0.1:8222/alive", timeout=60)
        pi.succeed("test -s /var/lib/vaultwarden/rsa_key.pem")
        pi.wait_for_unit("tailscale-serve-vault.service")
        assert advertised() == ["svc:vault"], advertised()

    with subtest("Executor refuses placeholder secrets and keeps the first-start marker"):
        write_executor_env("REPLACE_ME", "REPLACE_ME")
        pi.succeed("touch /var/lib/executor/initialize")
        pi.fail("systemctl start podman-executor.service")
        pi.succeed("test -e /var/lib/executor/initialize")
        assert advertised() == ["svc:vault"], advertised()
        # Ends the restart loop the failure started.
        pi.succeed("systemctl stop podman-executor.service")
        pi.succeed("systemctl reset-failed podman-executor.service")
        pi.succeed("test -e /var/lib/executor/initialize")

    with subtest("Executor's first start consumes the marker"):
        write_executor_env("test-secret-0123456789", "admin@example.test")
        try:
            pi.succeed("systemctl start podman-executor.service")
            pi.wait_until_succeeds("test -e /var/lib/executor/data.db", timeout=60)
            pi.succeed("test ! -e /var/lib/executor/initialize")
            pi.wait_for_unit("tailscale-serve-executor.service")
        except Exception:
            dump("podman-executor.service")
            raise
        assert advertised() == ["svc:executor", "svc:vault"], advertised()

    with subtest("Tailscale Serve's loopback port reaches Executor, and nothing else does"):
        body = pi.wait_until_succeeds("curl -fsS http://127.0.0.1:8302/", timeout=60)
        assert "executor-stub" in body, body
        assert "secret-key-length 22" in body, body
        assert "admin-email admin@example.test" in body, body
        pi.succeed("ip netns exec executor curl -fsS http://127.0.0.1:4788/")
        pi.fail("curl -fsS --max-time 5 http://10.231.0.2:4788/")

    with subtest("the namespace reaches the internet and the router's DNS, and nothing else"):
        ns = "ip netns exec executor curl -fsS --max-time 5"
        assert "router" in pi.succeed(f"{ns} http://203.0.113.1/")
        assert "router" in pi.succeed("podman exec executor wget -qO- http://internet.test/")
        resolv = pi.succeed("podman exec executor cat /etc/resolv.conf")
        assert "nameserver 10.0.0.1" in resolv, resolv
        # The same addresses work from the host, so a failure below is the
        # namespace's rules and not a missing server.
        pi.succeed("curl -fsS --max-time 5 http://10.0.0.1/")
        pi.succeed("curl -fsS --max-time 5 http://100.100.100.100/")
        pi.succeed("curl -fsS --max-time 5 http://127.0.0.1:8222/alive")
        pi.succeed("curl -fsS --max-time 5 http://10.0.0.67:9999/")
        pi.fail(f"{ns} http://10.0.0.1/")
        pi.fail(f"{ns} http://100.100.100.100/")
        pi.fail(f"{ns} http://10.0.0.67:9999/")
        pi.fail(f"{ns} http://10.231.0.1:9999/")
        pi.fail(f"{ns} http://10.231.0.1:8222/alive")
        pi.fail(f"{ns} http://127.0.0.1:8222/alive")

    with subtest("only the office subnet goes over the tunnel"):
        pi.wait_for_unit("openvpn-executor-vpn.service")
        pi.wait_until_succeeds(
            "test -n \"$(ip -n executor route show 10.1.10.0/24 dev tun0)\"", timeout=60
        )
        routes = pi.succeed("ip -n executor -4 route show")
        print(routes)
        assert "default via 10.231.0.1 dev vex-ns" in routes, routes
        for pushed in ["0.0.0.0/1", "128.0.0.0/1", "10.9.9.0"]:
            assert pushed not in routes, routes
        assert "office" in pi.succeed("ip netns exec executor curl -fsS --max-time 5 http://10.1.10.5/")
        assert "office" in pi.succeed("podman exec executor wget -qO- http://10.1.10.5/")
        pi.fail("ip netns exec executor curl -fsS --max-time 5 http://10.9.9.5/")
        assert "nameserver 10.0.0.1" in pi.succeed("podman exec executor cat /etc/resolv.conf")
        # The tunnel and its routes exist only in the namespace.
        pi.fail("ip link show tun0")
        pi.fail("curl -fsS --max-time 5 http://10.1.10.5/")
        # The office can't open connections to the Pi's end of the tunnel.
        tun_ip = pi.succeed(
            "ip -n executor -4 -o addr show dev tun0 | awk '{print $4}' | cut -d/ -f1"
        ).strip()
        office.fail(f"curl -fsS --max-time 5 http://{tun_ip}:4788/")

    with subtest("a stopped backend's service is withdrawn"):
        pi.succeed("systemctl stop vaultwarden.service")
        assert advertised() == ["svc:executor"], advertised()
        pi.succeed("systemctl start vaultwarden.service")
        pi.wait_for_unit("tailscale-serve-vault.service")
        assert advertised() == ["svc:executor", "svc:vault"], advertised()
        # Re-applying the serve config keeps the services whose backends run.
        pi.succeed("systemctl restart tailscale-serve-config.service")
        assert advertised() == ["svc:executor", "svc:vault"], advertised()

    with subtest("after a power cut, only services with a backend come back"):
        # The rollback step: move Vaultwarden's data aside.
        pi.succeed("systemctl stop vaultwarden.service")
        pi.succeed("mv /var/lib/vaultwarden /var/lib/vaultwarden.rolled-back")
        # What tailscaled would restore from before the cut.
        pi.succeed("touch /var/lib/fake-tailscale/svc:vault")
        # Without this the rename is still in the page cache when power goes.
        pi.succeed("sync")
        pi.crash()
        pi.start()
        pi.wait_for_unit("multi-user.target")
        pi.wait_for_unit("tailscale-serve-config.service")
        assert unit_state("vaultwarden.service") == "inactive"
        pi.wait_for_unit("podman-executor.service")
        pi.wait_for_unit("tailscale-serve-executor.service")
        assert advertised() == ["svc:executor"], advertised()
        pi.wait_until_succeeds("curl -fsS http://127.0.0.1:8302/", timeout=60)
  '';
}
