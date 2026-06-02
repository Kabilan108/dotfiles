{
  lib,
  pkgs,
  waylandCompositor,
  ...
}:
{
  config = lib.mkIf (waylandCompositor == "niri") {
    home.packages = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.libnotify
      pkgs.satty
      pkgs.wl-clipboard
    ];
  };
}
