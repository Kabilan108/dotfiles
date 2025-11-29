{ pkgs, theme, ... }:
let
  palette = theme.palette;
in
{
  services.dunst = {
    enable = true;
    iconTheme = {
      name = "WhiteSur-Dark";
      package = pkgs.whitesur-icon-theme;
    };
    settings = {
      global = {
        # display settings
        monitor = 0;
        follow = "mouse";
        transparency = 0;
        geometry = "150x1-30+20";
        indicate_hidden = true;
        shrink = false;

        # colors (using theme palette)
        background = "#${palette.base02}";
        foreground = "#${palette.base05}";
        frame_color = "#${palette.base0E}";
        separator_color = "#${palette.base00}";

        # styling
        separator_height = 1;
        frame_width = 0;
        notification_height = 0;
        alignment = "left";
        vertical_alignment = "center";
        corner_radius = 10;
        corners = "all";
        progress_bar = true;
        progress_bar_height = 8;
        progress_bar_frame_width = 0;
        progress_bar_corner_radius = 6;
        progress_bar_min_width = 150;
        progress_bar_max_width = 320;
        progress_bar_horizontal_alignment = "left";
        padding = 10;
        horizontal_padding = 15;

        # behavior
        sort = true;
        idle_threshold = 120;

        # typography
        font = "FiraMono Nerd Font 10";
        line_height = 0;
        markup = "full";
        format = "<b>%s</b>\\n%b";

        # advanced settings
        show_age_threshold = 60;
        word_wrap = true;
        ignore_newline = false;
        stack_duplicates = true;
        hide_duplicate_count = false;
        show_indicators = true;

        # icons
        icon_position = "right";
        min_icon_size = 18;
        max_icon_size = 18;

        # history
        sticky_history = true;
        history_length = 20;
        always_run_script = true;

        # window properties
        title = "Dunst";
        class = "Dunst";
        startup_notification = false;
        verbosity = "mesg";
        ignore_dbusclose = false;

        # mouse actions
        mouse_left_click = "close_current";
        mouse_middle_click = "do_action, close_current";
        mouse_right_click = "close_all";
      };

      urgency_low.timeout = 7;
      urgency_normal.timeout = 10;
      urgency_critical.foreground = "#${palette.base08}";
      urgency_critical.timeout = 15;

      "stack-brightness" = {
        appname = "brightctl";
        set_stack_tag = "brightctl";
        foreground = "#${palette.base0A}";
        format = "<b>%s</b>";
      };

      "stack-volume" = {
        set_stack_tag = "volctl";
        appname = "volctl";
        foreground = "#${palette.base0D}";
        format = "<b>%s</b>";
      };

      "stack-battery" = {
        appname = "battery";
        set_stack_tag = "battery";
        format = "<b>%s</b>\\n%b";
      };

      "battery-full" = {
        appname = "battery";
        category = "battery-full";
        foreground = "#${palette.base0B}";
      };

      "battery-low" = {
        appname = "battery";
        category = "battery-low";
        foreground = "#${palette.base09}";
      };

      "battery-critical" = {
        appname = "battery";
        category = "battery-critical";
        timeout = 0;
      };
    };
  };
}
