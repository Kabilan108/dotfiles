# VM test for the /dev/kvm group rule in modules/nixos/virt-manager.nix.
# Needs nested virtualisation on the host. From the repo root:
#   nix build --impure --expr 'import ./tests/kvm-access.nix { pkgs = (builtins.getFlake "git+file://${toString ./.}").inputs.nixpkgs.legacyPackages.x86_64-linux; }'
{ pkgs }:
let
  # A build that needs the kvm system feature, like a NixOS test, and records
  # whether its build user could open /dev/kvm inside the sandbox.
  probeExpr = pkgs.writeText "kvm-probe.nix" ''
    derivation {
      name = "kvm-probe";
      system = "x86_64-linux";
      builder = builtins.storePath "${pkgs.bash}" + "/bin/bash";
      args = [ "-c" '''
        if (exec 3<>/dev/kvm) 2>/dev/null; then echo open > $out; else echo denied > $out; fi
      ''' ];
      requiredSystemFeatures = [ "kvm" ];
    }
  '';

  probeDomain = pkgs.writeText "probe-domain.xml" ''
    <domain type='kvm'>
      <name>probe</name>
      <memory unit='MiB'>64</memory>
      <vcpu>1</vcpu>
      <os><type arch='x86_64' machine='q35'>hvm</type></os>
      <devices><emulator>/run/libvirt/nix-emulators/qemu-system-x86_64</emulator></devices>
    </domain>
  '';

  node =
    { extraModule }:
    { lib, ... }:
    {
      imports = [
        ../modules/nixos/virt-manager.nix
        extraModule
      ];
      boot.kernelModules = [ "kvm-amd" ];
      virtualisation.memorySize = 2048;
      users.users.kabilan.isNormalUser = true;
      users.users.svc = {
        isSystemUser = true;
        group = "svc";
      };
      users.groups.svc = { };
      nix.settings.substituters = lib.mkForce [ ];
      system.extraDependencies = [ pkgs.bash ];
      environment.systemPackages = [ pkgs.acl ];
      environment.etc."kvm-probe.nix".source = probeExpr;
      environment.etc."probe-domain.xml".source = probeDomain;
    };
in
pkgs.testers.runNixOSTest {
  name = "kvm-access";
  nodes.machine = node { extraModule = { }; };
  # The same rule without the nixbld ACL or qemu-libvirtd in kvm, to show
  # those are what keep the build and the libvirt guest working.
  nodes.control = node {
    extraModule =
      { lib, ... }:
      {
        users.groups.kvm.members = lib.mkForce [ "kabilan" ];
        services.udev.extraRules = lib.mkForce ''
          KERNEL=="kvm", GROUP="kvm", MODE="0660"
        '';
      };
  };

  testScript = ''
    start_all()
    for m in (machine, control):
        m.wait_for_unit("multi-user.target")
        m.wait_for_unit("libvirtd.socket")

    with subtest("/dev/kvm is root:kvm with a nixbld ACL and nothing for others"):
        assert machine.succeed("stat -c '%U %G' /dev/kvm").strip() == "root kvm"
        acl = machine.succeed("getfacl -p /dev/kvm")
        assert "group::rw-" in acl and "group:nixbld:rw-" in acl and "other::---" in acl, acl

    with subtest("kvm members open it, service accounts don't"):
        machine.succeed("runuser -u kabilan -- bash -c 'exec 3<>/dev/kvm'")
        machine.fail("runuser -u svc -- bash -c 'exec 3<>/dev/kvm'")

    with subtest("a kvm-feature build gets /dev/kvm through the nixbld ACL"):
        out = machine.succeed("runuser -u kabilan -- nix-build /etc/kvm-probe.nix --no-out-link").strip()
        assert machine.succeed(f"head -1 {out}").strip() == "open"
        out = control.succeed("runuser -u kabilan -- nix-build /etc/kvm-probe.nix --no-out-link").strip()
        assert control.succeed(f"head -1 {out}").strip() == "denied"

    with subtest("libvirt starts a KVM guest as qemu-libvirtd"):
        machine.succeed("virsh -c qemu:///system define /etc/probe-domain.xml")
        machine.succeed("virsh -c qemu:///system start probe")
        machine.succeed("pgrep -u qemu-libvirtd -f 'guest=probe'")
        control.succeed("virsh -c qemu:///system define /etc/probe-domain.xml")
        control.fail("virsh -c qemu:///system start probe")
  '';
}
