# Configure Framework 13 with AMD 7040 series
{ inputs, ... }:
{
  imports = [ inputs.nixos-hardware.nixosModules.framework-13-7040-amd ];
  services.fwupd.enable = true;

  services.printing.enable = true;

  programs.light.enable = true;
  users.extraGroups.video.members = [ "kabilan" ];

  services.fprintd.enable = true;
  security.pam.services = {
    sudo = {
      fprintAuth = true;
      unixAuth = true; # fallback to password
    };
    polkit-1 = {
      fprintAuth = true;
      unixAuth = true; # fallback to password
    };
  };
  security.polkit.enable = true;
}
