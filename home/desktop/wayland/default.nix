{
  pkgs,
  waylandCompositor,
  ...
}:
{
  imports = [
    ./screenshots.nix
    ./waybar.nix
    ./mako.nix
    ./walker.nix
    ./quickshell
    (./compositors + "/${waylandCompositor}")
  ];

  home.packages = with pkgs; [
    wl-clipboard
    wf-recorder
    wtype
  ];
}
