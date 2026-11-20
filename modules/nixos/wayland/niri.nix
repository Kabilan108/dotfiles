{
  inputs,
  pkgs,
  ...
}:
{
  nixpkgs.overlays = [
    inputs."niri-flake".overlays.niri
    (_final: prev: {
      libdisplay-info_0_2 = prev.callPackage ../../../packages/libdisplay-info/0.2.nix { };
      niri-unstable = prev.niri-unstable.overrideAttrs { doCheck = false; };
    })
  ];

  niri-flake.cache.enable = false;

  programs.niri = {
    enable = true;
    package = pkgs.niri-unstable;
  };

  security.pam.services.swaylock = { };

  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gnome ];

  environment.systemPackages = [ pkgs.xwayland-satellite ];
}
