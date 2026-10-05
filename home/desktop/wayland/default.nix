{
  lib,
  pkgs,
  waylandCompositors,
  ...
}:
{
  imports = [
    ./screenshots.nix
  ]
  ++ map (compositor: ./compositors + "/${compositor}") waylandCompositors
  ++ lib.optionals (lib.elem "niri" waylandCompositors) [ ./quickshell ];

  home.packages = with pkgs; [
    wl-clipboard
    wf-recorder
    wtype
  ];
}
