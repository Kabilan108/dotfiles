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
    hyprshot
    hyprpicker
    wl-clipboard
    wf-recorder
    wtype
  ];
}
