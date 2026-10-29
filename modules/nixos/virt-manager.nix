{ lib, pkgs, ... }:
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
}
