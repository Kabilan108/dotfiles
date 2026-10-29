# Throwaway probe for the agent VM policy draft (docs/plans/agent-vm/policy.md).
# Exercises the authorization and egress invariants in an isolated NixOS test;
# it is evidence for review, not a permanent test, and is not imported anywhere.
#
#   nix build -L --impure --expr \
#     '(import ./docs/plans/agent-vm/probe.nix { flake = builtins.getFlake (toString ./.); })'
{ flake }:
let
  pkgs = flake.nixosConfigurations.sietch.pkgs;

  libvirtPolkit = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.libvirt.unix.manage") {
        return subject.isInGroup("wheel") ? polkit.Result.AUTH_ADMIN : polkit.Result.NO;
      }
    });
  '';

  agentVmPolkit = ''
    polkit.addRule(function(action, subject) {
      if (action.id != "org.freedesktop.systemd1.manage-units" ||
          !subject.isInGroup("agent-vm")) {
        return polkit.Result.NOT_HANDLED;
      }
      var unit = action.lookup("unit");
      var verb = action.lookup("verb");
      if (typeof unit === "string" &&
          /^agent-vm@[a-z0-9][a-z0-9-]{0,31}\.service$/.test(unit) &&
          (verb == "start" || verb == "stop" || verb == "restart")) {
        return polkit.Result.YES;
      }
      return polkit.Result.NOT_HANDLED;
    });
  '';

  # Experiment only: does polkit see unit/verb details for transient units?
  transientExperimentPolkit = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          subject.isInGroup("agent-vm")) {
        polkit.log("manage-units unit=" + action.lookup("unit") + " verb=" + action.lookup("verb"));
        var unit = action.lookup("unit");
        if (typeof unit === "string" && /^probe-transient-[a-z]+\.service$/.test(unit)) {
          return polkit.Result.YES;
        }
      }
      return polkit.Result.NOT_HANDLED;
    });
  '';

  blockedV4 = [
    "127.0.0.0/8"
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "100.64.0.0/10"
    "169.254.0.0/16"
    "224.0.0.0/4"
  ];

  egressRules = ''
    iptables -w -N agent-vm-egress 2>/dev/null || iptables -w -F agent-vm-egress
    iptables -w -A agent-vm-egress -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
    iptables -w -A agent-vm-egress -d 127.0.0.53/32 -p udp --dport 53 -j RETURN
    iptables -w -A agent-vm-egress -d 127.0.0.53/32 -p tcp --dport 53 -j RETURN
    iptables -w -A agent-vm-egress -m addrtype --dst-type LOCAL -j REJECT
    ${pkgs.lib.concatMapStringsSep "\n" (
      net: "iptables -w -A agent-vm-egress -d ${net} -j REJECT"
    ) blockedV4}
    iptables -w -D OUTPUT -m owner --uid-owner agentvm -j agent-vm-egress 2>/dev/null || true
    iptables -w -I OUTPUT -m owner --uid-owner agentvm -j agent-vm-egress
    ip6tables -w -N agent-vm-egress6 2>/dev/null || ip6tables -w -F agent-vm-egress6
    ip6tables -w -A agent-vm-egress6 -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
    ip6tables -w -A agent-vm-egress6 -j REJECT
    ip6tables -w -D OUTPUT -m owner --uid-owner agentvm -j agent-vm-egress6 2>/dev/null || true
    ip6tables -w -I OUTPUT -m owner --uid-owner agentvm -j agent-vm-egress6
  '';

  probeScript = pkgs.writeShellScript "agent-vm-probe" ''
    set -u
    out="$RUNTIME_DIRECTORY/result"
    : > "$out"
    check() {
      if "''${@:2}" >/dev/null 2>&1; then echo "$1=reachable" >> "$out"; else echo "$1=blocked" >> "$out"; fi
    }
    echo "uid=$(id -un) groups=$(id -Gn | tr ' ' ,)" >> "$out"
    check loopback-service ${pkgs.curl}/bin/curl -s --max-time 3 http://127.0.0.1:8222/
    check resolver-stub ${pkgs.curl}/bin/curl -s --max-time 3 http://127.0.0.53:53/
    check lan-peer ${pkgs.curl}/bin/curl -s --max-time 3 http://192.168.1.2:8000/
    check public-peer ${pkgs.curl}/bin/curl -s --max-time 3 http://203.0.113.10:8000/
    check home-file ${pkgs.coreutils}/bin/cat /home/kabilan/secret
    check vault-file ${pkgs.coreutils}/bin/cat /vault/data
    check store-read ${pkgs.coreutils}/bin/ls /nix/store
    echo done >> "$out"
    exec ${pkgs.python3}/bin/python3 -m http.server 2222 --bind 127.0.0.1 --directory "$RUNTIME_DIRECTORY"
  '';

  # Socket-activated launcher variant: no polkit grant; the socket's group is the gate.
  socketProbeScript = pkgs.writeShellScript "agent-vm-socket-probe" ''
    set -u
    read -r id
    case "$id" in
      ""|*[!a-z0-9-]*) echo "error bad-id"; exit 2 ;;
    esac
    dir=/run/agent-vm-sock/$id
    mkdir "$dir" || { echo "error exists"; exit 2; }
    echo "ok $id"
    exec </dev/null >/dev/null
    RUNTIME_DIRECTORY=$dir
    out="$dir/result"
    check() {
      if "''${@:2}" >/dev/null 2>&1; then echo "$1=reachable" >> "$out"; else echo "$1=blocked" >> "$out"; fi
    }
    echo "uid=$(id -un) unit=$(${pkgs.coreutils}/bin/cat /proc/self/cgroup)" >> "$out"
    check loopback-service ${pkgs.curl}/bin/curl -s --max-time 3 http://127.0.0.1:8222/
    check lan-peer ${pkgs.curl}/bin/curl -s --max-time 3 http://192.168.1.2:8000/
    check public-peer ${pkgs.curl}/bin/curl -s --max-time 3 http://203.0.113.10:8000/
    check home-file ${pkgs.coreutils}/bin/cat /home/kabilan/secret
    check v6-peer ${pkgs.curl}/bin/curl -s -g --max-time 3 "http://[2001:db8:1::2]:8000/"
    check host-local-public ${pkgs.curl}/bin/curl -s --max-time 3 http://198.51.100.7:8333/
    check vsock-socket ${pkgs.python3}/bin/python3 -c 'import socket; socket.socket(socket.AF_VSOCK, socket.SOCK_STREAM)'
    check dbus-socket ${pkgs.coreutils}/bin/test -e /run/dbus/system_bus_socket
    check var-lib-other ${pkgs.coreutils}/bin/cat /var/lib/worldreadable/data
    check user-namespace ${pkgs.util-linux}/bin/unshare --user true
    echo done >> "$out"
    exec ${pkgs.coreutils}/bin/sleep 600
  '';

  socketClient = pkgs.writeShellScriptBin "agent-vm-client" ''
        exec ${pkgs.python3}/bin/python3 -c '
    import socket, sys
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect("/run/agent-vm-launch.sock")
    s.sendall((sys.argv[1] + "\n").encode())
    data = s.recv(200).decode().strip()
    print(data or "closed-without-reply")
    sys.exit(0 if data.startswith("ok") else 1)
    ' "$1"
  '';

  listener =
    addr: port:
    "${pkgs.python3}/bin/python3 -m http.server ${toString port} --bind ${addr} --directory /etc";
in
pkgs.testers.runNixOSTest {
  name = "agent-vm-policy-probe";

  nodes = {
    hardened =
      { lib, ... }:
      {
        virtualisation.libvirtd = {
          enable = true;
          qemu.runAsRoot = false;
        };
        security.polkit.extraConfig = lib.mkBefore (
          libvirtPolkit + transientExperimentPolkit + agentVmPolkit
        );

        users.users.kabilan = {
          isNormalUser = true;
          extraGroups = [
            "wheel"
            "agent-vm"
          ];
        };
        users.users.relapse = {
          isNormalUser = true;
          extraGroups = [ "libvirtd" ];
        };
        users.users.agentvm = {
          isSystemUser = true;
          group = "agentvm";
          extraGroups = [ "kvm" ];
        };
        users.groups.agentvm = { };
        users.groups.agent-vm = { };

        systemd.slices.agent-vm.sliceConfig = {
          MemoryMax = "2G";
          CPUQuota = "100%";
        };

        systemd.services."agent-vm@" = {
          description = "Agent VM %i (probe)";
          serviceConfig = {
            ExecStart = probeScript;
            User = "agentvm";
            Group = "agent-vm";
            SupplementaryGroups = [ "kvm" ];
            UMask = "0007";
            Slice = "agent-vm.slice";
            RuntimeDirectory = "agent-vm/%i";
            RuntimeDirectoryMode = "0750";
            StateDirectory = "agent-vm/instances/%i";
            StateDirectoryMode = "2770";
            RuntimeMaxSec = "10min";
            MemoryMax = "1G";
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            InaccessiblePaths = [ "-/vault" ];
            DevicePolicy = "closed";
            DeviceAllow = [ "/dev/kvm rw" ];
            CapabilityBoundingSet = "";
          };
        };

        systemd.sockets.agent-vm-launch = {
          wantedBy = [ "sockets.target" ];
          socketConfig = {
            ListenStream = "/run/agent-vm-launch.sock";
            SocketUser = "root";
            SocketGroup = "agent-vm";
            SocketMode = "0660";
            Accept = true;
            MaxConnections = 2;
          };
        };
        systemd.services."agent-vm-launch@" = {
          description = "Agent VM launched over socket (probe)";
          serviceConfig = {
            ExecStart = socketProbeScript;
            StandardInput = "socket";
            StandardOutput = "socket";
            StandardError = "journal";
            User = "agentvm";
            Group = "agent-vm";
            UMask = "0007";
            Slice = "agent-vm.slice";
            RuntimeMaxSec = "10min";
            MemoryMax = "1G";
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            TemporaryFileSystem = [
              "/run"
              "/var/lib"
            ];
            BindPaths = [ "/run/agent-vm-sock" ];
            CapabilityBoundingSet = "";
            CollectMode = "inactive-or-failed";
            RestrictAddressFamilies = [
              "AF_UNIX"
              "AF_INET"
              "AF_INET6"
            ];
            RestrictNamespaces = true;
            SystemCallArchitectures = "native";
            ProtectProc = "invisible";
          };
        };

        systemd.services.loopback-secret = {
          wantedBy = [ "multi-user.target" ];
          serviceConfig.ExecStart = listener "127.0.0.1" 8222;
        };
        systemd.services.host-local-listener = {
          wantedBy = [ "multi-user.target" ];
          serviceConfig.ExecStart = listener "0.0.0.0" 8333;
        };
        systemd.services.resolver-stub = {
          wantedBy = [ "multi-user.target" ];
          serviceConfig.ExecStart = listener "127.0.0.53" 53;
        };

        networking.firewall.extraCommands = egressRules;
        networking.interfaces.eth1.ipv4.addresses = lib.mkAfter [
          {
            address = "198.51.100.7";
            prefixLength = 32;
          }
        ];
        networking.interfaces.eth1.ipv4.routes = [
          {
            address = "203.0.113.10";
            prefixLength = 32;
            via = "192.168.1.2";
          }
        ];

        systemd.tmpfiles.rules = [
          "d /vault 0755 kabilan users -"
          "d /run/agent-vm-sock 3770 agentvm agent-vm -"
          "d /var/lib/worldreadable 0755 root root -"
          "f /var/lib/worldreadable/data 0644 root root - world-readable-state"
          "f /vault/data 0644 kabilan users - vault-contents"
          "f /home/kabilan/secret 0644 kabilan users - home-contents"
        ];

        environment.systemPackages = [
          pkgs.curl
          socketClient
        ];
      };

    peer =
      { lib, ... }:
      {
        networking.firewall.enable = false;
        networking.interfaces.eth1.ipv4.addresses = lib.mkAfter [
          {
            address = "203.0.113.10";
            prefixLength = 32;
          }
        ];
        systemd.services.peer-http = {
          wantedBy = [ "multi-user.target" ];
          serviceConfig.ExecStart = listener "::" 8000;
        };
      };
  };

  testScript = ''
    start_all()
    hardened.wait_for_unit("multi-user.target")
    hardened.wait_for_unit("libvirtd.socket")
    hardened.wait_for_unit("loopback-secret.service")
    hardened.wait_for_unit("resolver-stub.service")
    peer.wait_for_unit("peer-http.service")
    peer.wait_for_open_port(8000)

    def as_user(user, cmd):
        return hardened.execute(f"runuser -u {user} -- {cmd} 2>&1")

    def report(label, result):
        status, out = result
        print(f"PROBE {label}: exit={status} :: {out.strip()[:300]}")
        return status

    with subtest("control: kabilan reaches LAN and public peers directly"):
        assert report("kabilan-lan", as_user("kabilan", "curl -s --max-time 3 http://192.168.1.2:8000/")) == 0
        assert report("kabilan-public", as_user("kabilan", "curl -s --max-time 3 http://203.0.113.10:8000/")) == 0

    with subtest("libvirt system connection requires admin auth; root keeps access"):
        assert report("kabilan-virsh-system", as_user("kabilan", "virsh -c qemu:///system list --all")) != 0
        assert report("relapse-libvirtd-group", as_user("relapse", "virsh -c qemu:///system list --all")) != 0
        assert report("root-virsh-system", hardened.execute("virsh -c qemu:///system list --all 2>&1")) == 0
        assert report("kabilan-virsh-readonly", as_user("kabilan", "virsh -r -c qemu:///system list --all")) == 0

    with subtest("agent-vm group may start and stop instances"):
        assert report("start", as_user("kabilan", "systemctl start agent-vm@t1.service")) == 0
        hardened.wait_until_succeeds("grep -q done /run/agent-vm/t1/result", timeout=60)
        report("probe-result", hardened.execute("cat /run/agent-vm/t1/result"))
        result = hardened.succeed("cat /run/agent-vm/t1/result")
        assert "uid=agentvm" in result
        assert "loopback-service=blocked" in result
        assert "resolver-stub=reachable" in result
        assert "lan-peer=blocked" in result
        assert "public-peer=reachable" in result
        assert "home-file=blocked" in result
        assert "vault-file=blocked" in result
        assert "store-read=reachable" in result

    with subtest("inbound loopback connection to the VM process still works"):
        hardened.wait_for_open_port(2222)
        assert report("kabilan-to-vm-listener", as_user("kabilan", "curl -s --max-time 3 http://127.0.0.1:2222/result")) == 0
        assert report("kabilan-reads-runtime", as_user("kabilan", "cat /run/agent-vm/t1/result")) == 0

    with subtest("polkit grant stays scoped to start/stop of agent-vm instances"):
        assert report("set-property", as_user("kabilan", "systemctl set-property agent-vm@t1.service MemoryMax=infinity")) != 0
        assert report("transient-same-name", as_user("kabilan", "systemd-run --unit=agent-vm@t2 -p User=root id")) != 0
        assert report("transient-uid0", as_user("kabilan", "systemd-run --uid=0 id")) != 0
        assert report("transient-scope", as_user("kabilan", "systemd-run --scope --unit=agent-vm@t3 id")) != 0
        assert report("other-unit", as_user("kabilan", "systemctl stop sshd.service")) != 0
        assert report("bad-instance", as_user("kabilan", "systemctl start 'agent-vm@A_B.service'")) != 0
        assert report("enable", as_user("kabilan", "systemctl enable agent-vm@t4.service")) != 0
        assert report("daemon-reload", as_user("kabilan", "systemctl daemon-reload")) != 0
        report("kill-verb", as_user("kabilan", "systemctl kill agent-vm@t1.service"))
        report("reset-failed-verb", as_user("kabilan", "systemctl reset-failed agent-vm@t1.service"))
        report("relapse-start", as_user("relapse", "systemctl start agent-vm@t5.service"))
        report("transient-experiment", as_user("kabilan", "systemd-run --wait --unit=probe-transient-x -p User=root id -u"))
        report("polkit-log", hardened.execute("journalctl -u polkit.service --no-pager | grep 'manage-units unit=' | tail -20"))
        report("transient-check-uid", hardened.execute("journalctl -b --no-pager | grep -A2 'probe-transient-x' | tail -5"))
        assert report("restart", as_user("kabilan", "systemctl restart agent-vm@t1.service")) == 0
        assert report("stop", as_user("kabilan", "systemctl stop agent-vm@t1.service")) == 0

    with subtest("socket launcher: group gate, runs as agentvm, survives disconnect, MaxConnections caps concurrency"):
        hardened.wait_for_unit("agent-vm-launch.socket")
        assert report("sock-nonmember", as_user("relapse", "agent-vm-client x1")) != 0
        assert report("sock-bad-id", as_user("kabilan", "agent-vm-client 'A;rm'")) != 0
        assert report("sock-s1", as_user("kabilan", "agent-vm-client s1")) == 0
        assert report("sock-s2", as_user("kabilan", "agent-vm-client s2")) == 0
        hardened.wait_until_succeeds("grep -q done /run/agent-vm-sock/s1/result", timeout=60)
        report("sock-s1-result", hardened.execute("cat /run/agent-vm-sock/s1/result"))
        result = hardened.succeed("cat /run/agent-vm-sock/s1/result")
        assert "uid=agentvm" in result and "agent-vm.slice" in result
        assert "loopback-service=blocked" in result and "lan-peer=blocked" in result
        assert "public-peer=reachable" in result and "home-file=blocked" in result
        assert "v6-peer=blocked" in result and "host-local-public=blocked" in result
        assert "vsock-socket=blocked" in result and "dbus-socket=blocked" in result
        assert "var-lib-other=blocked" in result and "user-namespace=blocked" in result
        assert report("kabilan-v6-peer", as_user("kabilan", "curl -s -g --max-time 3 'http://[2001:db8:1::2]:8000/'")) == 0
        assert report("kabilan-host-local", as_user("kabilan", "curl -s --max-time 3 http://198.51.100.7:8333/")) == 0
        report("sock-units", hardened.execute("systemctl list-units --no-legend 'agent-vm-launch@*'"))
        assert report("sock-s3-over-limit", as_user("kabilan", "agent-vm-client s3")) != 0
        assert report("sock-kabilan-systemctl-stop", as_user("kabilan", "systemctl stop 'agent-vm-launch@*'")) != 0
        report("sock-kabilan-kill", as_user("kabilan", "pkill -u agentvm -f sleep"))
        assert report("sock-still-running", hardened.execute("pgrep -u agentvm -c -f sleep")) == 0
  '';
}
