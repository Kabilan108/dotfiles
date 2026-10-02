{
  inputs,
  pkgs,
  ...
}:
{
  # Use the system's glibc so Niri can load newer Mesa drivers.
  nixpkgs.overlays = [
    inputs."niri-flake".overlays.niri
    (_final: prev: {
      # This Niri revision requires 0.2, removed from newer Nixpkgs.
      libdisplay-info_0_2 = prev.callPackage (
        inputs."niri-flake".inputs.nixpkgs + "/pkgs/by-name/li/libdisplay-info/0.2.nix"
      ) { };
    })
  ];

  niri-flake.cache.enable = true;

  programs.niri = {
    enable = true;
    package = pkgs.niri-unstable;
  };

  security.pam.services.swaylock = { };

  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gnome ];

  environment.systemPackages = [ pkgs.xwayland-satellite ];
}
