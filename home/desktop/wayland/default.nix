{ pkgs, ... }:
{
  imports = [
    ./compositors/niri
    ./quickshell
    ./screenshots.nix
  ];

  home.packages = with pkgs; [
    wl-clipboard
    wf-recorder
    wtype
  ];
}
