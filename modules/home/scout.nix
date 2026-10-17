{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  scout = inputs.scout.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  # scout: keyboard-first file manager. The NixOS side registers its file
  # chooser portal (modules/nixos/desktop-wayland.nix).
  # Nautilus ships an org.freedesktop.FileManager1 service file too; priority
  # makes scout's the one in the profile, so "Show in folder" opens scout.
  home.packages = [ (lib.hiPrio scout) ];

  xdg.mimeApps.defaultApplications."inode/directory" = "scout.desktop";

  # Shadows niri's packaged niri-portals.conf; keep its defaults and route
  # only the file chooser to scout, falling back to GNOME's.
  xdg.configFile."xdg-desktop-portal/niri-portals.conf".text = ''
    [preferred]
    default=gnome;gtk;
    org.freedesktop.impl.portal.Access=gtk;
    org.freedesktop.impl.portal.Notification=gtk;
    org.freedesktop.impl.portal.Secret=oo7-portal;gnome-keyring;
    org.freedesktop.impl.portal.FileChooser=scout;gnome;gtk;
  '';
}
