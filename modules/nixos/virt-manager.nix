{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.virt-manager.enable = true;
  virtualisation.libvirtd = {
    enable = true;
    qemu.runAsRoot = false;
    qemu.vhostUserPackages = [ pkgs.virtiofsd ];
  };
  # System libvirt is root-equivalent: ask for an admin password on every
  # connection, without polkit's grant caching. mkBefore keeps this ahead of
  # the libvirtd module's rule that passes members of the libvirtd group.
  security.polkit.extraConfig = lib.mkBefore ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.libvirt.unix.manage" || action.id == "org.libvirt.unix.monitor") {
        return subject.isInGroup("wheel") ? polkit.Result.AUTH_ADMIN : polkit.Result.NO;
      }
    });
  '';
  virtualisation.spiceUSBRedirection.enable = true;

  # systemd ships /dev/kvm as 0666, so every service account can use it.
  # Limit it to the kvm group; qemu-libvirtd needs membership now that libvirt
  # runs QEMU unprivileged. Nix's build sandbox drops supplementary groups, so
  # kvm membership would not reach NixOS tests. Their primary group survives,
  # so nixbld gets an ACL entry instead. static_node makes udevd apply the
  # mode again each time it starts; otherwise systemd's own static_node rule
  # resets /dev/kvm to 0666 on a udevd restart.
  services.udev.extraRules = ''
    KERNEL=="kvm", GROUP="kvm", MODE="0660", OPTIONS+="static_node=kvm", RUN+="${pkgs.acl}/bin/setfacl -m g:nixbld:rw $env{DEVNAME}"
  '';
  users.groups.kvm.members = [
    "kabilan"
    "qemu-libvirtd"
  ];
}
