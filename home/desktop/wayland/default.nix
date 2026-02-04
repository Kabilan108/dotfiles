{
  pkgs,
  waylandCompositor,
  ...
}:
{
  imports = [
    ./waybar.nix
    ./mako.nix
    ./walker.nix
    (./compositors + "/${waylandCompositor}")
  ];

  home.packages = with pkgs; [
    wl-clipboard
    wf-recorder
    wtype
  ];
}
