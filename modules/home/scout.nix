{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [ inputs.scout.homeManagerModules.default ];

  # scout: keyboard-first file manager. The NixOS side registers its file
  # chooser portal (modules/nixos/desktop-wayland.nix).
  programs.scout = {
    enable = true;
    # Nautilus ships an org.freedesktop.FileManager1 service file too; priority
    # makes scout's the one in the profile, so "Show in folder" opens scout.
    package = lib.hiPrio pkgs.scout;
    # g + key. gd already follows the XDG downloads folder and gr is ~/repos.
    bookmarks = {
      w = "~/work";
      m = "~/media";
      e = "~/experiments";
    };
  };

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
