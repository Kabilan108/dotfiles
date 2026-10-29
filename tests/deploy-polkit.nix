# VM test for the receiver's polkit rule and deploy-trigger, with a stand-in
# receiver (tests/test_deploy_gate.py covers the real one). From the repo root:
#   nix build --impure --expr 'import ./tests/deploy-polkit.nix { pkgs = (builtins.getFlake "git+file://${toString ./.}").inputs.nixpkgs.legacyPackages.x86_64-linux; }'
{ pkgs }:
pkgs.testers.runNixOSTest {
  name = "deploy-polkit";
  nodes.machine =
    { lib, pkgs, ... }:
    {
      imports = [ ../modules/nixos/deploy ];
      networking.hostName = "sietch";
      users.users.kabilan = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
      };
      users.users.agent.isNormalUser = true;
      systemd.services.deploy-receiver.serviceConfig.ExecStart = lib.mkForce (
        pkgs.writeShellScript "stand-in-receiver" ''
          echo "stand-in receiver ran as $(id -un)"
          echo "deploy/sietch/20261029T100000Z 0123abc" > /var/lib/deploy-receiver/deployed
        ''
      );
    };
  testScript = ''
    machine.wait_for_unit("multi-user.target")

    out = machine.succeed("su - kabilan -c deploy-trigger")
    assert "stand-in receiver ran as root" in out, out
    assert "sietch runs deploy/sietch/20261029T100000Z 0123abc" in out, out

    for verb in ["stop", "restart", "reload-or-restart"]:
        machine.fail(f"su - kabilan -c 'systemctl {verb} deploy-receiver.service'")
    machine.fail("su - kabilan -c 'systemctl start nix-gc.service'")
    machine.fail("su - agent -c 'systemctl start deploy-receiver.service'")
  '';
}
