{ lib, pkgs, ... }:
{
  programs.virt-manager.enable = true;
  virtualisation.libvirtd = {
    enable = true;
    qemu.runAsRoot = false;
    qemu.vhostUserPackages = [ pkgs.virtiofsd ];
  };
  security.polkit.extraConfig = lib.mkBefore ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.libvirt.unix.manage" || action.id == "org.libvirt.unix.monitor") {
        return subject.isInGroup("wheel") ? polkit.Result.AUTH_ADMIN : polkit.Result.NO;
      }
    });
  '';
  virtualisation.spiceUSBRedirection.enable = true;

  services.udev.extraRules = ''
    KERNEL=="kvm", GROUP="kvm", MODE="0660", OPTIONS+="static_node=kvm", RUN+="${pkgs.acl}/bin/setfacl -m g:nixbld:rw $env{DEVNAME}"
  '';
  users.groups.kvm.members = [
    "kabilan"
    "qemu-libvirtd"
  ];
}
