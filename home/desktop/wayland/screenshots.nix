{
  inputs,
  lib,
  pkgs,
  waylandCompositors,
  ...
}:
let
  omasnap = inputs.omasnap.packages.${pkgs.stdenv.hostPlatform.system}.omasnap;
in
{
  config = lib.mkIf (lib.elem "niri" waylandCompositors) {
    home.packages = [ omasnap ];
  };
}
