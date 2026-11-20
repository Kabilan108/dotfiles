{ pkgs }:
pkgs.testers.runNixOSTest {
  name = "deploy-trigger";
  nodes.machine =
    { lib, pkgs, ... }:
    {
      imports = [ ../modules/nixos/deploy ];
      networking.hostName = "sietch";
      system.configurationRevision = "0123456789abcdef0123456789abcdef01234567";
      users.users.kabilan = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
      };
      users.users.agent.isNormalUser = true;
      services.journald.settings.Journal.MaxLevelConsole = lib.mkForce "info";
      dotfiles.deploy.receiverProgram = "${pkgs.writeShellScript "stand-in-receiver" ''
        echo "stand-in receiver ran as $(id -un)"
        echo run >> /run/stand-in-runs
        if [ -e /run/noisy-deploy ]; then
          for i in $(seq 20000); do
            echo "<7>noisy deploy log line $i, which a client that never reads would block"
          done
          sleep 5
        fi
        if [ -e /run/fail-deploy ]; then
          echo "stand-in receiver failing"
          exit 3
        fi
        echo "deploy/fleet/20261029T100000Z 0123abc" > /var/lib/deploy-receiver/deployed
      ''}";
      systemd.services.blocker.serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.coreutils}/bin/sleep 600";
      };
      systemd.services.queued = {
        after = [ "blocker.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.coreutils}/bin/true";
        };
      };
    };
  testScript = ''
    def queued_job_waits():
        machine.succeed("systemctl list-jobs --no-legend | grep -q 'queued.service'")

    def stand_in_runs():
        return int(machine.succeed("cat /run/stand-in-runs 2>/dev/null | wc -l").strip())

    def accepted():
        return int(machine.succeed("systemctl show --property=NAccepted --value deploy-trigger.socket").strip())

    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("deploy-trigger.socket")
    machine.succeed("test \"$(stat -c '%U:%G %a' /run/deploy-trigger.sock)\" = 'root:deploy-trigger 660'")
    machine.succeed("systemctl cat deploy-trigger@.service | grep -qx RuntimeMaxSec=30")

    machine.succeed("test \"$(stat -c '%U:%G %a' /run/fleet-switch.lock)\" = 'root:root 600'")
    machine.fail("su - kabilan -c 'flock --nonblock /run/fleet-switch.lock true'")

    machine.succeed("systemctl start --no-block blocker.service")
    machine.succeed("systemctl start --no-block queued.service")
    queued_job_waits()

    out = machine.succeed("su - kabilan -c deploy-trigger")
    assert "stand-in receiver ran as root" in out, out
    assert "sietch deployed deploy/fleet/20261029T100000Z 0123abc" in out, out
    assert "sietch runs 0123456789abcdef0123456789abcdef01234567" in out, out
    queued_job_waits()

    reply = machine.succeed("su - kabilan -c '${pkgs.socat}/bin/socat -u UNIX-CONNECT:/run/deploy-trigger.sock -'").strip()
    assert reply.startswith("deploy-trigger: queued job "), reply
    job = reply.rsplit(" ", 1)[1]
    machine.wait_until_succeeds(f"! systemctl list-jobs --no-legend | grep -q '^{job} '", timeout=60)
    machine.wait_until_succeeds("test \"$(systemctl show --property=ActiveState --value deploy-receiver.service)\" = inactive", timeout=60)
    machine.succeed(f"su - kabilan -c 'grep -Eq \"^{job} [0-9a-f]{{32}} exit:0$\" /run/deploy-receiver/runs'")
    machine.succeed("test \"$(stat -c '%U:%G %a' /run/deploy-receiver/runs)\" = 'root:root 644'")

    machine.succeed("touch /run/fail-deploy")
    out = machine.fail("su - kabilan -c deploy-trigger")
    assert "stand-in receiver failing" in out, out
    machine.succeed("rm /run/fail-deploy")

    for command in [
        "start deploy-receiver.service",
        "--job-mode=flush start deploy-receiver.service",
        "stop deploy-receiver.service",
        "restart deploy-receiver.service",
        "start blocker.service",
        "stop blocker.service",
        "restart nix-daemon.service",
    ]:
        machine.fail(f"su - kabilan -c 'systemctl {command}'")
    queued_job_waits()

    runs = stand_in_runs()
    machine.fail("su - agent -c deploy-trigger")
    assert stand_in_runs() == runs

    machine.succeed("touch /run/noisy-deploy")
    runs, before = stand_in_runs(), accepted()
    for i in range(6):
        machine.succeed(
            f"systemd-run --unit=never-reads-{i} --uid=kabilan "
            "sh -c '${pkgs.coreutils}/bin/sleep 600 | ${pkgs.socat}/bin/socat -u STDIN UNIX-CONNECT:/run/deploy-trigger.sock'"
        )
    machine.wait_until_succeeds(f"test $(systemctl show --property=NAccepted --value deploy-trigger.socket) -ge {before + 4}", timeout=30)
    machine.wait_until_succeeds("test -z \"$(systemctl list-units --all --no-legend 'deploy-trigger@*')\"", timeout=60)
    machine.wait_until_succeeds("test \"$(systemctl show --property=ActiveState --value deploy-receiver.service)\" = inactive", timeout=120)
    assert stand_in_runs() > runs
    machine.succeed("rm /run/noisy-deploy")
    out = machine.succeed("su - kabilan -c deploy-trigger")
    assert "sietch deployed deploy/fleet/20261029T100000Z 0123abc" in out, out
    machine.succeed("systemctl stop 'never-reads-*'")

    machine.succeed("systemctl --job-mode=flush start --no-block deploy-receiver.service")
    machine.wait_until_fails("systemctl list-jobs --no-legend | grep -q 'queued.service'")
    machine.fail("systemctl is-active queued.service")
  '';
}
