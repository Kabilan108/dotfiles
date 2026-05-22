{ config, pkgs, ... }:
let
  colors = config.lib.stylix.colors.withHashtag;
in
{
  services.mako = {
    enable = true;
    settings = {
      font = "FiraMono Nerd Font 11";
      text-color = "${colors.base05}";
      background-color = "${colors.base00}cc";
      border-color = "${colors.base0D}";
      border-size = 2;
      border-radius = 10;
      padding = "14,18";
      margin = "12";
      width = 350;
      height = 100;
      anchor = "top-right";
      progress-color = "over ${colors.base02}";
      default-timeout = 5000;
      icon-path = "${pkgs.whitesur-icon-theme}/share/icons/WhiteSur-dark";
      max-icon-size = 64;
      icons = true;
      layer = "overlay";
      outer-margin = "8,8,0,0";

      "urgency=low" = {
        default-timeout = 4000;
        background-color = "${colors.base00}cc";
        border-color = "${colors.base03}";
      };
      "urgency=normal" = {
        default-timeout = 5000;
        background-color = "${colors.base00}cc";
        border-color = "${colors.base0D}";
        text-color = "${colors.base05}";
      };
      "urgency=critical" = {
        default-timeout = 7000;
        background-color = "${colors.base00}cc";
        border-color = "${colors.base08}";
        text-color = "${colors.base05}";
      };

      "app-name=battery" = {
        group-by = "app-name";
        border-color = "${colors.base0B}";
      };
    };
  };
}
