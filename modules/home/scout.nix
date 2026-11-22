{
  inputs,
  ...
}:
{
  imports = [ inputs.scout.homeManagerModules.default ];

  programs.scout = {
    enable = true;
    bookmarks = {
      w = "~/work";
      m = "~/media";
      e = "~/experiments";
    };
  };

  xdg.mimeApps.defaultApplications."inode/directory" = "scout.desktop";

  xdg.configFile."xdg-desktop-portal/niri-portals.conf".text = ''
    [preferred]
    default=gnome;gtk;
    org.freedesktop.impl.portal.Access=gtk;
    org.freedesktop.impl.portal.Notification=gtk;
    org.freedesktop.impl.portal.Secret=gnome-keyring;
    org.freedesktop.impl.portal.FileChooser=scout;gnome;gtk;
  '';
}
