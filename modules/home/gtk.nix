{ pkgs, config, ... }:
let
  gtk-theme = "WhiteSur-Dark";
  gtk-icon-theme = "Adwaita";
  cursor-theme = "catppuccin-mocha-mauve-cursors";
in
{
  home.sessionVariables.GTK_THEME = gtk-theme;

  # Configure XDG portals to use GTK backend for settings
  xdg.configFile."xdg-desktop-portal/portals.conf".text = ''
    [preferred]
    default=gtk
    org.freedesktop.impl.portal.ScreenCast=hyprland
    org.freedesktop.impl.portal.Screenshot=hyprland
    org.freedesktop.impl.portal.GlobalShortcuts=hyprland
  '';

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = gtk-theme;
    };
  };

  gtk = {
    enable = true;

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };

    iconTheme = {
      name = gtk-icon-theme;
      package = pkgs.adwaita-icon-theme;
    };
    theme = {
      name = gtk-theme;
      package = pkgs.whitesur-gtk-theme;
    };
    cursorTheme = {
      name = cursor-theme;
      package = pkgs.catppuccin-cursors.mochaMauve;
      size = 18;
    };
  };

}
