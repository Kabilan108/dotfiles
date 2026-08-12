{
  inputs,
  lib,
  pkgs,
  waylandCompositor,
  ...
}:
let
  omasnap = inputs.omasnap.packages.${pkgs.stdenv.hostPlatform.system}.omasnap;
in
{
  config = lib.mkIf (waylandCompositor == "niri") {
    home.packages = [
      omasnap
      pkgs.coreutils
      pkgs.findutils
      pkgs.satty
      pkgs.wl-clipboard
    ];
  };
}
