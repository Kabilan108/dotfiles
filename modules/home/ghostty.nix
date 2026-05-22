{ ... }:
{
  stylix.targets.ghostty.enable = true;

  programs.ghostty = {
    enable = true;
    settings = {
      clipboard-read = "allow";
      clipboard-write = "allow";
      clipboard-trim-trailing-spaces = true;

      shell-integration = "bash";
      shell-integration-features = "no-title";
      app-notifications = "no-clipboard-copy";

      adw-toolbar-style = "flat";
      gtk-tabs-location = "bottom";
      gtk-wide-tabs = "false";

      font-family = "FiraMono Nerd Font Mono";

      confirm-close-surface = false;

      window-decoration = "none";
      window-padding-x = 4;
      window-padding-y = 4;
      window-theme = "ghostty";

      keybind = [
        "alt+0=unbind"
        "alt+1=unbind"
        "alt+2=unbind"
        "alt+3=unbind"
        "alt+4=unbind"
        "alt+5=unbind"
        "alt+6=unbind"
        "alt+7=unbind"
        "alt+8=unbind"
        "alt+9=unbind"
        "ctrl+shift+t=unbind"
        "ctrl+shift+p=unbind"
      ];
    };
  };
}
