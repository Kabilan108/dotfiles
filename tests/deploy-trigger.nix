# VM test for the deploy-trigger socket and broker, with a stand-in receiver
# (tests/test_deploy_gate.py covers the real one). From the repo root:
#   nix build --impure --expr 'import ./tests/deploy-trigger.nix { pkgs = (builtins.getFlake "git+file://${toString ./.}").inputs.nixpkgs.legacyPackages.x86_64-linux; }'
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
      systemd.services.deploy-receiver.serviceConfig.ExecStart = lib.mkForce (
        pkgs.writeShellScript "stand-in-receiver" ''
          echo "stand-in receiver ran as $(id -un)"
          echo run >> /run/stand-in-runs
          if [ -e /run/fail-deploy ]; then
            echo "stand-in receiver failing"
            exit 3
          fi
          echo "deploy/sietch/20261029T100000Z 0123abc" > /var/lib/deploy-receiver/deployed
        ''
      );
      # queued.service waits in the job queue for as long as blocker runs.
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
        return machine.succeed("cat /run/stand-in-runs 2>/dev/null | wc -l").strip()

    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("deploy-trigger.socket")
    machine.succeed("test \"$(stat -c '%U:%G %a' /run/deploy-trigger.sock)\" = 'root:deploy-trigger 660'")

    machine.succeed("systemctl start --no-block blocker.service")
    machine.succeed("systemctl start --no-block queued.service")
    queued_job_waits()

    out = machine.succeed("su - kabilan -c deploy-trigger")
    assert "stand-in receiver ran as root" in out, out
    assert "sietch deployed deploy/sietch/20261029T100000Z 0123abc" in out, out
    assert "sietch runs 0123456789abcdef0123456789abcdef01234567" in out, out
    queued_job_waits()

    # The receiver's failure reaches the caller as the exit status.
    machine.succeed("touch /run/fail-deploy")
    out = machine.fail("su - kabilan -c deploy-trigger")
    assert "stand-in receiver failing" in out, out
    machine.succeed("rm /run/fail-deploy")

    # kabilan can't drive systemd directly, in any job mode.
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

    # Only members of deploy-trigger may connect.
    runs = stand_in_runs()
    machine.fail("su - agent -c deploy-trigger")
    assert stand_in_runs() == runs

    # Control: a flush start does cancel the queued job, so the checks above
    # would have seen it.
    machine.succeed("systemctl --job-mode=flush start --no-block deploy-receiver.service")
    machine.wait_until_fails("systemctl list-jobs --no-legend | grep -q 'queued.service'")
    machine.fail("systemctl is-active queued.service")
  '';
}
