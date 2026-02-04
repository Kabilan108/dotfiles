{ pkgs, ... }:
{
  programs.niri.enable = true;

  security.pam.services.swaylock = { };

  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gnome ];

  environment.systemPackages = [ pkgs.xwayland-satellite ];
}
