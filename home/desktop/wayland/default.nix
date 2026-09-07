{
  lib,
  pkgs,
  waylandCompositor,
  ...
}:
{
  imports = [
    ./screenshots.nix
    ./waybar.nix
    ./walker.nix
    (./compositors + "/${waylandCompositor}")
  ]
  ++ lib.optionals (waylandCompositor == "niri") [ ./quickshell ];

  home.packages = with pkgs; [
    wl-clipboard
    wf-recorder
    wtype
  ];
}
