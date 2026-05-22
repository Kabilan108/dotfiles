{ config, theme, ... }:
let
  inherit (config.lib.formats.rasi) mkLiteral;

  colors = with theme; {
    bg = "#${palette.base00}"; # base
    fg = "#${palette.base05}"; # text
    primary = "#${palette.base08}"; # red
    accent = "#${palette.base0E}"; # mauve/lavender
    border = "#${palette.base0E}"; # lavender
    selected = "#${palette.base02}"; # surface0
    surface0 = "#${palette.base02}"; # surface0
    surface1 = "#${palette.base03}"; # surface1
  };
in
{
  # TODO: verify this X11-only launcher theme against Stylix's desktop helper color guide.
  home.file.".config/rofi/menus".source = ./menus;

  programs.rofi = {
    enable = true;
    cycle = true;
    font = "FiraMono Nerd Font 12";
    terminal = "ghostty";

    extraConfig = {
      modi = "drun,run,window,combi,ssh";
      case-sensitive = false;
      filter = "";
      scroll-method = 0;
      normalize-match = true;
      icon-theme = "Papirus";
      steal-focus = false;

      # Matching settings
      matching = "normal";
      tokenize = true;

      # SSH settings
      ssh-command = "{terminal} -e ssh {host} [-p {port}]";
      parse-hosts = true;
      parse-known-hosts = true;

      # Drun settings
      drun-categories = "";
      drun-match-fields = "name,generic,exec,categories,keywords";
      drun-display-format = "{name} [<span weight='light' size='small'><i>({generic})</i></span>]";
      drun-show-actions = false;
      drun-url-launcher = "xdg-open";
      drun-use-desktop-cache = false;
      drun-reload-desktop-cache = true;

      # Run settings
      run-command = "{cmd}";
      run-list-command = "";
      run-shell-command = "{terminal} -e {cmd}";

      # Window switcher settings
      window-match-fields = "title,class,role,name,desktop";
      window-command = "wmctrl -i -R {window}";
      window-format = "{w} | {c} | {t:0}";
      window-thumbnail = false;

      # Combi settings
      combi-modi = "drun,run";
      combi-hide-mode-prefix = false;
      combi-display-format = "{mode} {text}";

      # History and sorting
      disable-history = false;
      sorting-method = "normal";
      max-history-size = 25;

      # Display settings
      show-icons = true;
      display-keys = " ";
      display-ssh = " ";
      display-drun = " ";
      display-window = " ";
      display-combi = " ";
      display-filebrowser = "";

      # Misc settings
      sort = false;
      threads = 0;
      click-to-exit = true;

      # File browser settings
      filebrowser-cmd = "ghostty -e nvim";
      filebrowser-directory = "/home";
      filebrowser-directories-first = true;
      filebrowser-sorting-method = "name";

      # Timeout settings
      timeout-action = "kb-cancel";
      timeout-delay = 0;
    };

    theme = {
      "*" = {
        font = "FiraMono Nerd Font 12";
      };

      mainbox.background-color = mkLiteral colors.bg;

      window = {
        width = mkLiteral "20%";
        border = mkLiteral "2px";
        border-color = mkLiteral colors.border;
        background-color = mkLiteral colors.bg;
        border-radius = mkLiteral "5px";
      };

      inputbar = {
        children = mkLiteral "[ prompt, entry ]";
        background-color = mkLiteral colors.bg;
        border-radius = mkLiteral "0";
        padding = mkLiteral "0";
      };

      prompt = {
        background-color = mkLiteral colors.primary;
        padding = mkLiteral "6px";
        text-color = mkLiteral colors.bg;
        border-radius = mkLiteral "5px";
        margin = mkLiteral "20px 0px 0px 20px";
      };

      "textbox-prompt-colon" = {
        expand = false;
        str = "";
      };

      entry = {
        padding = mkLiteral "6px";
        margin = mkLiteral "20px 20px 0px 10px";
        text-color = mkLiteral colors.fg;
        background-color = mkLiteral colors.surface0;
        border-radius = mkLiteral "5px";
      };

      listview = {
        border = mkLiteral "0px 0px 0px";
        padding = mkLiteral "6px 0px 0px";
        margin = mkLiteral "10px 20px 20px 20px";
        columns = 1;
        lines = 10;
        background-color = mkLiteral colors.bg;
      };

      element = {
        padding = mkLiteral "5px 10px 5px 10px";
        background-color = mkLiteral colors.bg;
        text-color = mkLiteral colors.fg;
        border-radius = mkLiteral "5px";
      };

      "element-icon" = {
        size = mkLiteral "25px";
        padding = mkLiteral "0px 10px 0px 0px";
      };

      "element selected" = {
        background-color = mkLiteral colors.selected;
        text-color = mkLiteral colors.accent;
      };

      "element-text, element-icon, mode-switcher" = {
        background-color = mkLiteral "inherit";
        text-color = mkLiteral "inherit";
      };

      button = {
        padding = mkLiteral "10px";
        background-color = mkLiteral colors.accent;
        vertical-align = mkLiteral "0.5";
        horizontal-align = mkLiteral "0.5";
      };

      "button selected" = {
        background-color = mkLiteral colors.bg;
        text-color = mkLiteral colors.primary;
      };

      message = {
        background-color = mkLiteral colors.accent;
        margin = mkLiteral "2px";
        padding = mkLiteral "2px";
        border-radius = mkLiteral "5px";
      };

      textbox = {
        padding = mkLiteral "6px";
        margin = mkLiteral "20px 0px 0px 20px";
        text-color = mkLiteral colors.primary;
        background-color = mkLiteral colors.accent;
      };
    };
  };
}
