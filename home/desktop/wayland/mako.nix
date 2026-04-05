{ pkgs, theme, ... }:
let
  palette = theme.palette;
in
{
  services.mako = {
    enable = true;
    settings = {
      font = "FiraMono Nerd Font 11";
      text-color = "#${palette.base05}";
      background-color = "#${palette.base00}cc";
      border-size = 2;
      border-radius = 10;
      padding = "14,18";
      margin = "12";
      width = 350;
      height = 100;
      anchor = "top-right";
      progress-color = "over #${palette.base0D}40";
      default-timeout = 5000;
      icon-path = "${pkgs.whitesur-icon-theme}/share/icons/WhiteSur-dark";
      max-icon-size = 64;
      icons = true;
      layer = "overlay";
      outer-margin = "8,8,0,0";

      "urgency=low" = {
        default-timeout = 4000;
        background-color = "#${palette.base00}80";
        border-color = "#${palette.base04}";
      };
      "urgency=normal" = {
        default-timeout = 5000;
        background-color = "#${palette.base00}80";
        border-color = "#${palette.base04}";
        text-color = "#${palette.base0D}";
      };
      "urgency=critical" = {
        default-timeout = 7000;
        background-color = "#${palette.base08}80";
        border-color = "#${palette.base04}";
        text-color = "#${palette.base08}";
      };

"app-name=battery" = {
        group-by = "app-name";
        border-color = "#${palette.base0B}";
      };
    };
  };
}
