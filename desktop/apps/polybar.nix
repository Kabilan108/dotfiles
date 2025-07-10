{
  lib,
  pkgs,
  theme,
  ...
}:
let
  palette = theme.palette;
in
{
  services.polybar = {
    enable = true;
    script = lib.readFile ../../home/bin/start-polybar;
    package = pkgs.polybar.override {
      i3Support = true;
      pulseSupport = true;
    };
    settings = {
      "settings" = {
        screenchange-reload = true;
        pseudo-transparency = false;
      };

      "bar/main" = {
        width = "100%";
        height = "25pt";
        radius = 10;
        fixed-center = true;
        background = "#${palette.base00}";
        foreground = "#${palette.base05}";

        line-size = "2pt";
        border-top = 4;
        border-left = 4;
        border-right = 4;
        border-bottom = "2pt";

        padding-left = 1;
        padding-right = 1;
        module-margin = 1;

        separator = "|";
        separator-foreground = "#${palette.base03}";

        font-0 = "FiraMono Nerd Font:size=12;4";
        font-1 = "FiraMono Nerd Font:size=12;4";

        cursor-click = "pointer";
        enable-ipc = true;
        monitor = "\${env:MONITOR}";

        modules-left = "menu i3 xwindow";
        modules-center = "date";
        modules-right = "pulseaudio memory cpu battery systray";
      };

      "module/menu" = {
        type = "custom/text";
        format = " ";
        format-foreground = "#${palette.base09}";
        content-padding = 1;
        click-left = "rofi -show combi";
        click-right = "$HOME/.config/rofi/menus/exit";
      };

      "module/systray" = {
        type = "internal/tray";
        tray-size = 20;
      };

      "module/i3" = {
        type = "internal/i3";
        pin-workspaces = true;
        show-urgent = true;
        index-sort = true;
        enable-click = true;
        enable-scroll = true;
        wrapping-scroll = true;
        reverse-scroll = false;
        fuzzy-match = true;

        format = "<label-state> <label-mode>";

        label-mode = "%mode%";
        label-mode-padding = 1;
        label-mode-foreground = "#${palette.base09}";
        label-mode-underline = "#${palette.base09}";

        label-focused = "%name%";
        label-focused-background = "#${palette.base02}";
        label-focused-underline = "#${palette.base0D}";
        label-focused-padding = 1;

        label-unfocused = "%name%";
        label-unfocused-padding = 1;
        label-unfocused-foreground = "#${palette.base03}";

        label-visible = "%name%";
        label-visible-padding = 1;

        label-urgent = "%name%";
        label-urgent-background = "#${palette.base02}";
        label-urgent-foreground = "#${palette.base08}";
        label-urgent-underline = "#${palette.base08}";
        label-urgent-padding = 1;
      };

      "module/xwindow" = {
        type = "internal/xwindow";
        label = "%title:0:60:...%";
      };

      "module/pulseaudio" = {
        type = "internal/pulseaudio";
        format-volume = "<ramp-volume>  <label-volume>";

        label-volume = "%percentage%%";
        label-volume-foreground = "#${palette.base0C}";

        label-muted = "󰝟 ";
        label-muted-foreground = "#${palette.base03}";

        ramp-volume-0 = "";
        ramp-volume-1 = "";
        ramp-volume-2 = "";
        ramp-volume-3 = "";
        ramp-volume-4 = "";
        ramp-volume-5 = "";
        ramp-volume-6 = "";
        ramp-volume-foreground = "#${palette.base0C}";
      };

      "module/memory" = {
        type = "internal/memory";
        interval = 2;
        format-prefix = " ";
        format-prefix-foreground = "#${palette.base07}";
        label = "%percentage_used:2%%";
        label-foreground = "#${palette.base07}";
      };

      "module/cpu" = {
        type = "internal/cpu";
        interval = 2;
        format-prefix = " ";
        format-prefix-foreground = "#${palette.base0A}";
        label = "%percentage:2%%";
        label-foreground = "#${palette.base0A}";
      };

      "module/date" = {
        type = "internal/date";
        interval = 1;
        date = "%m-%d-%Y %H:%M:%S";
        date-alt = "%H:%M";
        label = "%date%";
        label-foreground = "#${palette.base0D}";
      };

      "module/battery" = {
        type = "internal/battery";
        battery = "BAT1";
        adapter = "AC";
        full-at = 90;

        format-charging = "<animation-charging> <label-charging>";
        format-charging-foreground = "#${palette.base0B}";
        format-discharging = "<ramp-capacity> <label-discharging>";
        format-discharging-foreground = "#${palette.base06}";
        format-full = "<ramp-capacity> <label-full>";

        label-charging = "%percentage%%";
        label-discharging = "%percentage%%";
        label-full = "Full";

        # Battery capacity icons
        ramp-capacity-0 = "󰁺";
        ramp-capacity-1 = "󰁻";
        ramp-capacity-2 = "󰁼";
        ramp-capacity-3 = "󰁽";
        ramp-capacity-4 = "󰁾";
        ramp-capacity-5 = "󰁿";
        ramp-capacity-6 = "󰂀";
        ramp-capacity-7 = "󰂁";
        ramp-capacity-8 = "󰂂";
        ramp-capacity-9 = "󰁹";

        # Charging animation
        animation-charging-0 = "󰢜";
        animation-charging-1 = "󰂆";
        animation-charging-2 = "󰂇";
        animation-charging-3 = "󰂈";
        animation-charging-4 = "󰢝";
        animation-charging-framerate = 750;
      };
    };
  };
}
