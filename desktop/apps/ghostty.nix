{ theme, ... }:
let
  palette = theme.palette;
in
{
  programs.ghostty = {
    enable = true;
    settings = {
      clipboard-read = "allow";
      clipboard-write = "allow";
      clipboard-trim-trailing-spaces = true;

      shell-integration = "bash";
      app-notifications = "no-clipboard-copy";

      adw-toolbar-style = "flat";
      gtk-tabs-location = "bottom";
      gtk-wide-tabs = "false";

      font-family = "FiraMono Nerd Font Mono";

      window-decoration = false;
      window-padding-x = 4;
      window-padding-y = 4;
      window-theme = "ghostty";

      theme = "dotfiles";

      keybind = [
        "alt+0=unbind"
        "alt+1=unbind"
        "alt+2=unbind"
        "alt+3=unbind"
        "alt+4=unbind"
        "alt+5=unbind"
        "alt+6=unbind"
        "alt+7=unbind"
        "alt+8=unbind"
        "alt+9=unbind"
        "ctrl+shift+t=unbind"
      ];
    };
    themes = {
      dotfiles = {
        background = "#${palette.base00}";
        foreground = "#${palette.base05}";

        selection-background = "#${palette.base02}";
        selection-foreground = "#${palette.base00}";
        palette = [
          "0=#${palette.base00}"
          "1=#${palette.base08}"
          "2=#${palette.base0B}"
          "3=#${palette.base0A}"
          "4=#${palette.base0D}"
          "5=#${palette.base06}"
          "6=#${palette.base0C}"
          "7=#${palette.base05}"
          "8=#${palette.base03}"
          "9=#${palette.base08}"
          "10=#${palette.base0B}"
          "11=#${palette.base0A}"
          "12=#${palette.base0D}"
          "13=#${palette.base06}"
          "14=#${palette.base0C}"
          "15=#${palette.base07}"
        ];
      };
    };
  };
}
