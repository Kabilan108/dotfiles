{
  inputs,
  pkgs,
  ...
}:
let
  omasnap = inputs.omasnap.packages.${pkgs.stdenv.hostPlatform.system}.omasnap;
in
{
  home.packages = [ omasnap ];
}
