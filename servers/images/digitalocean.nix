{
  pkgs ? import <nixpkgs> { },
}:
let
  config = {
    imports = [ <nixpkgs/nixos/modules/virtualisation/digital-ocean-image.nix> ];
    system.stateVersion = "25.05";
  };
in
(pkgs.nixos config).digitalOceanImage
