import ./compile.nix {
  schemaVersion = 2;

  identity = {
    id = "stillsuit.catppuccin-mocha";
    name = "Catppuccin Mocha";
    mode = "dark";
    description = "The canonical Catppuccin Mocha theme for the Stillsuit production shell.";
  };

  palette = {
    neutral = {
      crust = "#11111b";
      scrim = "#0b0b12";
      mantle = "#181825";
      base = "#1e1e2e";
      surface0 = "#313244";
      surface1 = "#45475a";
      surface2 = "#585b70";
      overlay0 = "#6c7086";
      overlay1 = "#7f849c";
      overlay2 = "#9399b2";
      subtext0 = "#a6adc8";
      subtext1 = "#bac2de";
      text = "#cdd6f4";
    };
    chromatic = {
      rosewater = "#f5e0dc";
      selection = "#2b3a57";
      accentHover = "#a9c9fb";
      accentPressed = "#6d9ee8";
      dangerFill = "#3b222b";
      flamingo = "#f2cdcd";
      pink = "#f5c2e7";
      magenta = "#cba6f7";
      red = "#f38ba8";
      maroon = "#eba0ac";
      peach = "#fab387";
      yellow = "#f9e2af";
      green = "#a6e3a1";
      teal = "#94e2d5";
      cyan = "#89dceb";
      sapphire = "#74c7ec";
      blue = "#89b4fa";
      lavender = "#b4befe";
    };
  };

  typography = {
    bodyFamily = "Noto Sans";
    monoFamily = "JetBrainsMono Nerd Font";
    iconFamily = "Material Symbols Rounded";
    baseSize = 13;
    captionSize = 11;
    headingSize = 17;
    weightRegular = 400;
    weightMedium = 500;
    weightBold = 700;
  };

  metrics = {
    spaceUnit = 4;
    radiusSmall = 5;
    radiusMedium = 7;
    radiusLarge = 11;
    barHeight = 28;
    barOuterGap = 0;
    barInnerGap = 7;
    iconSmall = 15;
    iconMedium = 18;
    iconLarge = 24;
    panelWidth = 380;
    panelPadding = 16;
    rowHeight = 38;
  };

  motion = {
    fast = 66;
    normal = 99;
    slow = 143;
    distanceSmall = 4;
    distanceMedium = 10;
    easing = "out-cubic";
  };

  effects = {
    surfaceOpacity = 0.95;
    blurEnabled = true;
    blurRadius = 24;
    shadowOpacity = 0.5;
  };
}
