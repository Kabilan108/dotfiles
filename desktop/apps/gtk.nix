{ pkgs, ... }:
let
  gtk-theme = "WhiteSur-Dark";
  gtk-icon-theme = "WhiteSur";
in
{
  home.sessionVariables.GTK_THEME = gtk-theme;
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
  gtk = {
    enable = true;
    iconTheme = {
      name = gtk-icon-theme;
      package = pkgs.whitesur-icon-theme;
    };
    theme = {
      name = gtk-theme;
      package = pkgs.whitesur-gtk-theme;
    };
  };

}
