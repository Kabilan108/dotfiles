{
  inputs,
  pkgs,
  ...
}:
let
  niriPackage = inputs."niri-flake".packages.${pkgs.system}.niri-stable.overrideAttrs (_: {
    doCheck = false;
  });
in
{
  niri-flake.cache.enable = true;

  programs.niri = {
    enable = true;
    package = niriPackage;
  };

  security.pam.services.swaylock = { };

  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gnome ];

  environment.systemPackages = [ pkgs.xwayland-satellite ];
}
