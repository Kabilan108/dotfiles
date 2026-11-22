{ inputs, ... }:
{
  imports = [ inputs.nixos-hardware.nixosModules.framework-13-7040-amd ];
  services.fwupd.enable = true;
  services.upower.enable = true;

  hardware.acpilight.enable = true;
  users.extraGroups.video.members = [ "kabilan" ];

  services.fprintd.enable = true;
  security.pam.services = {
    login.fprintAuth = false;
    sudo = {
      fprintAuth = true;
      unixAuth = true;
    };
    polkit-1 = {
      fprintAuth = true;
      unixAuth = true;
    };
  };
  security.polkit.enable = true;
}
