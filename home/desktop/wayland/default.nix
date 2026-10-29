{ inputs, pkgs, ... }:
{
  imports = [
    ./compositors/niri
    ./quickshell
  ];

  home.packages = with pkgs; [
    inputs.omasnap.packages.${pkgs.stdenv.hostPlatform.system}.omasnap
    wl-clipboard
    wf-recorder
    wtype
  ];
}
