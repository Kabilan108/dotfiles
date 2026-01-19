{ pkgs, ... }:
{
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = [ "kabilan" ];
  virtualisation.libvirtd = {
    enable = true;
    qemu.vhostUserPackages = [ pkgs.virtiofsd ];
  };
  virtualisation.spiceUSBRedirection.enable = true;
}
