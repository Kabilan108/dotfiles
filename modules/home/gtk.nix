{
  config,
  lib,
  pkgs,
  waylandCompositor,
  ...
}:
let
  gtk-theme = "WhiteSur-Dark";
  gtk-icon-theme = "Adwaita";
  cursor-theme = "catppuccin-mocha-mauve-cursors";

  # Libadwaita apps refuse to load named GTK themes, so the gresource at
  # resource:///org/gnome/theme/gtk.css is never registered and the CSS
  # import chain that home-manager generates silently fails.
  # Fix: extract every gtk-4.0 gresource to plain files so file:// imports work.
  extractGtkGresources =
    themePkg:
    pkgs.runCommand "${themePkg.name}-gtk4-extracted"
      {
        nativeBuildInputs = [ pkgs.glib.dev ];
      }
      ''
        cp -r ${themePkg} $out
        chmod -R u+w $out

        find $out/share/themes -path '*/gtk-4.0/gtk.gresource' | while read -r gresource; do
          target="$(dirname "$gresource")"
          for res in $(gresource list "$gresource"); do
            relative=''${res#/org/gnome/theme/}
            mkdir -p "$(dirname "$target/$relative")"
            gresource extract "$gresource" "$res" > "$target/$relative"
          done
        done
      '';
in
{
  home.sessionVariables.GTK_THEME = gtk-theme;

  xdg.configFile."xdg-desktop-portal/portals.conf" = lib.mkIf (waylandCompositor == "hyprland") {
    text = ''
      [preferred]
      default=gtk
      org.freedesktop.impl.portal.ScreenCast=hyprland
      org.freedesktop.impl.portal.Screenshot=hyprland
      org.freedesktop.impl.portal.GlobalShortcuts=hyprland
    '';
  };

  # color-scheme is the portal-based setting that libadwaita reads for dark mode.
  # gtk-application-prefer-dark-theme only works for GTK3 and non-libadwaita GTK4.
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

    iconTheme = {
      name = gtk-icon-theme;
      package = pkgs.adwaita-icon-theme;
    };
    theme = {
      name = gtk-theme;
      package = extractGtkGresources pkgs.whitesur-gtk-theme;
    };
    cursorTheme = {
      name = cursor-theme;
      package = pkgs.catppuccin-cursors.mochaMauve;
      size = 18;
    };
  };

}
