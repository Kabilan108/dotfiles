{
  schemaVersion = 1;

  identity = {
    id = "stillsuit.catppuccin-mocha";
    name = "Catppuccin Mocha";
    mode = "dark";
  };

  palette = {
    neutral = {
      crust = "#11111b";
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

  colors = {
    surface = {
      canvas = "#1e1e2e";
      panel = "#181825";
      raised = "#313244";
      hover = "#45475a";
    };
    text = {
      primary = "#cdd6f4";
      secondary = "#bac2de";
      tertiary = "#a6adc8";
      onAccent = "#11111b";
    };
    border = {
      subtle = "#313244";
      normal = "#45475a";
      focus = "#89b4fa";
    };
    status = {
      info = "#89dceb";
      success = "#a6e3a1";
      warning = "#f9e2af";
      danger = "#f38ba8";
    };
  };

  controls = {
    normal = {
      fill = "#313244";
      text = "#cdd6f4";
      border = "#45475a";
    };
    hover = {
      fill = "#45475a";
      text = "#cdd6f4";
      border = "#585b70";
    };
    active = {
      fill = "#89b4fa";
      text = "#11111b";
      border = "#89b4fa";
    };
    focus = {
      fill = "#313244";
      text = "#cdd6f4";
      border = "#89b4fa";
    };
    disabled = {
      fill = "#181825";
      text = "#6c7086";
      border = "#313244";
    };
  };

  typography = {
    family = "Noto Sans";
    monospaceFamily = "FiraMono Nerd Font";
    baseSize = 13;
    scale = 1.0;
    weightNormal = 400;
    weightMedium = 500;
    weightBold = 700;
  };

  geometry = {
    radius = 5;
    density = 1.0;
    barHeight = 38;
    panelGap = 8;
  };

  motion = {
    fast = 120;
    medium = 180;
    slow = 260;
  };
}
