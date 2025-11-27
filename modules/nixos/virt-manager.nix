{ ... }:
{
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = [ "kabilan" ];
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;
}
