{ config, ... }:
let
  inherit (config.lib.formats.rasi) mkLiteral;

  colors = config.lib.stylix.colors.withHashtag;
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

      mainbox.background-color = mkLiteral colors.base00;

      window = {
        width = mkLiteral "20%";
        border = mkLiteral "2px";
        border-color = mkLiteral colors.base0E;
        background-color = mkLiteral colors.base00;
        border-radius = mkLiteral "5px";
      };

      inputbar = {
        children = mkLiteral "[ prompt, entry ]";
        background-color = mkLiteral colors.base00;
        border-radius = mkLiteral "0";
        padding = mkLiteral "0";
      };

      prompt = {
        background-color = mkLiteral colors.base08;
        padding = mkLiteral "6px";
        text-color = mkLiteral colors.base00;
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
        text-color = mkLiteral colors.base05;
        background-color = mkLiteral colors.base02;
        border-radius = mkLiteral "5px";
      };

      listview = {
        border = mkLiteral "0px 0px 0px";
        padding = mkLiteral "6px 0px 0px";
        margin = mkLiteral "10px 20px 20px 20px";
        columns = 1;
        lines = 10;
        background-color = mkLiteral colors.base00;
      };

      element = {
        padding = mkLiteral "5px 10px 5px 10px";
        background-color = mkLiteral colors.base00;
        text-color = mkLiteral colors.base05;
        border-radius = mkLiteral "5px";
      };

      "element-icon" = {
        size = mkLiteral "25px";
        padding = mkLiteral "0px 10px 0px 0px";
      };

      "element selected" = {
        background-color = mkLiteral colors.base02;
        text-color = mkLiteral colors.base0E;
      };

      "element-text, element-icon, mode-switcher" = {
        background-color = mkLiteral "inherit";
        text-color = mkLiteral "inherit";
      };

      button = {
        padding = mkLiteral "10px";
        background-color = mkLiteral colors.base0E;
        vertical-align = mkLiteral "0.5";
        horizontal-align = mkLiteral "0.5";
      };

      "button selected" = {
        background-color = mkLiteral colors.base00;
        text-color = mkLiteral colors.base08;
      };

      message = {
        background-color = mkLiteral colors.base0E;
        margin = mkLiteral "2px";
        padding = mkLiteral "2px";
        border-radius = mkLiteral "5px";
      };

      textbox = {
        padding = mkLiteral "6px";
        margin = mkLiteral "20px 0px 0px 20px";
        text-color = mkLiteral colors.base08;
        background-color = mkLiteral colors.base0E;
      };
    };
  };
}
