{ config, theme, ... }:
let
  palette = theme.palette;
in
{
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        disable_loading_bar = false;
        hide_cursor = true;
        no_fade_in = false;
      };

      background = [
        {
          path = config.dotfiles.wallpaper.lockscreen;
          blur_passes = 2;
          blur_size = 5;
          contrast = 0.8916;
          brightness = 0.8172;
          vibrancy = 0.1696;
          vibrancy_darkness = 0.0;
          color = "rgb(${palette.base00})";
        }
      ];

      # user box shape (frosted glass effect)
      shape = [
        {
          size = "300, 60";
          color = "rgba(255, 255, 255, 0.1)";
          rounding = -1;
          border_size = 0;
          position = "0, -580";
          halign = "center";
          valign = "center";
        }
      ];

      input-field = [
        {
          size = "300, 60";
          outline_thickness = 0;
          dots_size = 0.2;
          dots_spacing = 0.2;
          dots_center = true;
          outer_color = "rgba(0, 0, 0, 0)";
          inner_color = "rgba(255, 255, 255, 0.1)";
          font_color = "rgb(${palette.base05})";
          fade_on_empty = false;
          placeholder_text = "<i><span foreground=\"##${palette.base05}\">Password</span></i>";
          font_family = "FiraMono Nerd Font";
          position = "0, -650";
          halign = "center";
          valign = "center";

          # maintain frosted glass effect on state changes
          check_color = "rgba(180, 255, 180, 0.2)";
          fail_color = "rgba(255, 180, 180, 0.2)";
        }
      ];

      label = [
        # Time
        {
          text = "cmd[update:1000] echo \"<span>$(date +\"%I:%M\")</span>\"";
          font_size = 120;
          font_family = "FiraMono Nerd Font";
          color = "rgba(${palette.base05}, 0.70)";
          position = "0, 550";
          halign = "center";
          valign = "center";
        }
        # Date
        {
          text = "cmd[update:1000] echo \"$(date +\"%A, %B %d\")\"";
          font_size = 25;
          font_family = "FiraMono Nerd Font";
          color = "rgba(${palette.base05}, 0.70)";
          position = "0, 650";
          halign = "center";
          valign = "center";
        }
        # Username
        {
          text = "    $USER";
          font_size = 18;
          font_family = "FiraMono Nerd Font";
          color = "rgba(${palette.base05}, 0.80)";
          position = "0, -580";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };
}
