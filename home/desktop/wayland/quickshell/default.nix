{
  pkgs,
  config,
  lib,
  ...
}:
let
  homeDir = "/home/kabilan";
  colors = config.lib.stylix.colors.withHashtag;
  fontSans = config.stylix.fonts.sansSerif.name or "Noto Sans";
  fontMono = config.stylix.fonts.monospace.name or "FiraMono Nerd Font";
  transparent = alpha: color: "#${alpha}${lib.removePrefix "#" color}";
in
{
  home.packages = [ pkgs.quickshell ];

  xdg.configFile."quickshell/osd".source =
    config.lib.file.mkOutOfStoreSymlink "${homeDir}/dotfiles/home/desktop/wayland/quickshell/osd";

  xdg.configFile."quickshell/stillsuit".source =
    config.lib.file.mkOutOfStoreSymlink "${homeDir}/dotfiles/home/desktop/wayland/quickshell/stillsuit";

  xdg.configFile."quickshell/theme/stylix.json".text = builtins.toJSON {
    palette = {
      crust = colors.base00;
      mantle = colors.base01;
      base = colors.base00;
      surface0 = colors.base02;
      surface1 = colors.base03;
      surface2 = colors.base04;
      overlay0 = colors.base03;
      overlay1 = colors.base04;
      overlay2 = colors.base05;
      subtext0 = colors.base04;
      subtext1 = colors.base05;
      text = colors.base05;
      rosewater = colors.base06;
      flamingo = colors.base0F;
      pink = colors.base0E;
      mauve = colors.base0E;
      red = colors.base08;
      maroon = colors.base08;
      peach = colors.base09;
      yellow = colors.base0A;
      green = colors.base0B;
      teal = colors.base0C;
      sky = colors.base0C;
      sapphire = colors.base0D;
      blue = colors.base0D;
      lavender = colors.base07;
    };
    semantic = {
      panelBg = transparent "e0" colors.base01;
      panelBgSoft = transparent "c7" colors.base00;
      panelBgStrong = transparent "f0" colors.base01;
      panelBorder = colors.base02;
      panelBorderStrong = colors.base03;
      panelSurface = transparent "b8" colors.base02;
      panelSurfaceHover = transparent "cc" colors.base03;
      panelSurfaceActive = transparent "d9" colors.base04;
      foreground = colors.base05;
      dimText = colors.base04;
      mutedText = colors.base03;
      accent = colors.base0D;
      success = colors.base0B;
      warning = colors.base0A;
      urgent = colors.base08;
      info = colors.base0C;
      osdTrack = transparent "1f" colors.base05;
      osdFillMuted = colors.base03;
      shadow = transparent "66" colors.base00;
    };
    typography = {
      fontFamily = fontMono;
      bodyFontFamily = fontSans;
      fontSizeSmall = 11;
      fontSizeMedium = 13;
      fontSizeLarge = 16;
      fontSizeTitle = 14;
      fontSizeIcon = 20;
      fontSizeIconLarge = 24;
    };
    geometry = {
      radiusSmall = 6;
      radiusMedium = 12;
      radiusLarge = 22;
      radiusPill = 9999;
      paddingSmall = 8;
      paddingMedium = 14;
      paddingLarge = 20;
      borderWidth = 1;
      panelWidth = 380;
      osdWidth = 360;
      osdHeight = 58;
      screenMargin = 12;
      panelGap = 8;
    };
    animation = {
      fast = 120;
      medium = 180;
      slow = 260;
      osdHideMs = 1500;
      notificationDefaultMs = 5000;
      notificationLowMs = 4000;
    };
  };

  xdg.configFile."quickshell/stillsuit-policy.json".text = builtins.toJSON {
    notifications = {
      dndBypass = {
        critical = true;
        appNames = [
          "battery"
          "Battery"
        ];
        appUrgencies = [
          {
            appName = "notify-send";
            urgency = "critical";
          }
        ];
        summaryPatterns = [ ];
      };
    };
  };
}
