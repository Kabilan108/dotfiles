{
  config,
  pkgs,
  ...
}:
let
  gtk-theme = "WhiteSur-Dark";
  gtk-icon-theme = "Adwaita";
  cursor-theme = "catppuccin-mocha-mauve-cursors";

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

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      inherit gtk-theme;
    };
  };

  gtk = {
    enable = true;

    gtk4.theme = config.gtk.theme;

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
