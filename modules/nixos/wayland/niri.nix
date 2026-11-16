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
      libdisplay-info_0_2 = prev.callPackage ../../../packages/libdisplay-info/0.2.nix { };
      # Its checkPhase rebuilds the crate graph for cargo test: about 7 of the
      # 20 minutes niri takes in the cache CI. Upstream CI runs the tests.
      niri-unstable = prev.niri-unstable.overrideAttrs { doCheck = false; };
    })
  ];

  # niri is built against our nixpkgs, so niri.cachix.org never has it.
  niri-flake.cache.enable = false;

  programs.niri = {
    enable = true;
    package = pkgs.niri-unstable;
  };

  security.pam.services.swaylock = { };

  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gnome ];

  environment.systemPackages = [ pkgs.xwayland-satellite ];
}
