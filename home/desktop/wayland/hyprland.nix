{
  pkgs,
  theme,
  inputs,
  ...
}:
let
  mod = "SUPER";
  palette = theme.palette;
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;
    systemd.enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;

    plugins = [ inputs.hy3.packages.${pkgs.system}.hy3 ];

    settings = {
      # TODO: machine-specific settings
      monitor = [
        "eDP-1,2256x1504@60Hz,0x0,1" # laptop display
        "desc:AOC CU34G2XP 1Q1R6HA001347,3440x1440@60Hz,2256x0,1" # right of laptop
        "desc:Dell Inc. DELL S2721H 7B6XB23,1920x1080@60Hz,168x-1080,1" # centered above laptop
      ];

      env = [
        "XCURSOR_SIZE,18"
        "XCURSOR_THEME,catppuccin-mocha-mauve-cursors"
        "QT_QPA_PLATFORMTHEME,qt5ct"
      ];

      general = {
        gaps_in = 4;
        gaps_out = 4;
        border_size = 2;
        "col.active_border" = "rgba(${palette.base0D}ee)";
        "col.inactive_border" = "rgba(${palette.base03}aa)";
        layout = "hy3";
      };

      decoration = {
        rounding = 5;
        blur = {
          enabled = true;
          size = 3;
          passes = 2;
        };
        shadow.enabled = false;
      };

      animations = {
        enabled = true;
        bezier = [
          "myBezier, 0.05, 0.9, 0.1, 1.05"
          "linear, 0, 0, 1, 1"
        ];
        animation = [
          "windows, 1, 2, myBezier"
          "windowsMove, 1, 2, myBezier"
          "border, 1, 3, default"
          "fade, 1, 4, default"
          "workspaces, 1, 1, default"
          "layers, 1, 2, linear, fade"
        ];
      };

      input = {
        kb_layout = "us";
        follow_mouse = 1;
        touchpad = {
          natural_scroll = false;
        };
        sensitivity = 0;
      };

      cursor = {
        no_hardware_cursors = false;
      };

      "plugin:hy3" = {
        autotile.enable = false;
        tabs = {
          height = 30;
          padding = 6;
          radius = 5;
          border_width = 2;
          render_text = true;
          text_center = true;
          text_font = "FiraMono Nerd Font";
          text_height = 11;
          blur = true;
          opacity = 1.0;

          # active tab (focused tab in focused container)
          "col.active" = "rgba(${palette.base00}aa)";
          "col.active.border" = "rgba(${palette.base0D}ee)";
          "col.active.text" = "rgb(${palette.base0D})";

          # active tab on unfocused monitor
          "col.active_alt_monitor" = "rgba(${palette.base00}aa)";
          "col.active_alt_monitor.border" = "rgba(${palette.base03}aa)";
          "col.active_alt_monitor.text" = "rgb(${palette.base04})";

          # focused tab in unfocused container (you can see it but container not active)
          "col.focused" = "rgba(${palette.base00}aa)";
          "col.focused.border" = "rgba(${palette.base0C}aa)";
          "col.focused.text" = "rgb(${palette.base0C})";

          # inactive tabs
          "col.inactive" = "rgba(${palette.base00}aa)";
          "col.inactive.border" = "rgba(${palette.base02}88)";
          "col.inactive.text" = "rgb(${palette.base05})";

          # urgent tabs - red border/text to stand out
          "col.urgent" = "rgba(${palette.base00}aa)";
          "col.urgent.border" = "rgba(${palette.base08}ee)";
          "col.urgent.text" = "rgb(${palette.base08})";

          # locked tabs - purple accent
          "col.locked" = "rgba(${palette.base00}aa)";
          "col.locked.border" = "rgba(${palette.base0E}aa)";
          "col.locked.text" = "rgb(${palette.base0E})";

          "col.text.active" = "rgb(${palette.base05})";
          "col.text.inactive" = "rgb(${palette.base04})";
        };
      };

      layerrule = [
        "blur, waybar"
        "blurpopups, waybar"
        "ignorealpha 0.2, waybar"

        "blur, notifications"
        "ignorealpha 0.2, notifications"
      ];

      windowrulev2 = [
        "float, initialTitle:^(floating-nvim)$"
        "size 600 900, initialTitle:^(floating-nvim)$"

        "float, class:^(org.pulseaudio.pavucontrol)$"
        "pin, class:^(org.pulseaudio.pavucontrol)$"

        "float, class:^(org.nomacs.ImageLounge)$"
        "pin, class:^(org.nomacs.ImageLounge)$"

        "float, class:^(org.gnome.Nautilus)$"
        "pin, class:^(org.gnome.Nautilus)$"

        "float, class:^(.blueman-manager-wrapped)$"
        "pin, class:^(.blueman-manager-wrapped)$"

        "float, title:^(Extension:).*$"
        "pin, title:^(Extension:).*$"

        "float, class:^(Signal)$"
        "pin, class:^(Signal)$"

        "float, class:^(zoom)$"
        "pin, class:^(zoom)$"

        "float, class:^(TelegramDesktop)$"

        "float, class:^(Evince)$"
        "float, class:^(steam)$"

        "float, class:^(com.dictator.overlay)$"
        "float, class:^(Emulator)$"

        "workspace 9 silent, class:^(spotify)$"
        "workspace 2 silent, class:^(obsidian)$"
        "workspace 2 silent, class:^(Slack)$"
        "workspace 1 silent, class:^(google-chrome)$"
        "workspace 1 silent, class:^(zen-beta)$"

        "workspace 1 silent, class:^(chrome-.*)$"
        "float, class:^(chrome-.*)$"

        # picture-in-picture
        "float, title:^(Picture.in.[Pp]icture)$"
        "pin, title:^(Picture.in.[Pp]icture)$"
        "keepaspectratio, title:^(Picture.in.[Pp]icture)$"

        "opacity 0.99 0.95, class:^.*$"
        "opacity 1.0 1.0, title:(YouTube|Zoom)"
      ];

      workspace = [
        "name:0, monitor:eDP-1, default:true"
      ];

      exec-once = [
        "hyprpaper"
        "mako"
        "nm-applet --indicator"
        "blueman-applet"
        "hypridle"
        "obsidian"
        "[workspace name:0 silent] ghostty"
        "$HOME/dotfiles/bin/battery-watcher"
      ];

      binds.allow_workspace_cycles = true;

      "$mod" = mod;

      bind = [
        # launcher
        "$mod, d, exec, walker --set combi --width 450"
        "$mod, Tab, exec, walker --provider windows --width 600 --height 400"
        "$mod SHIFT, E, exec, walker --provider menus:power --width 300 --height 400"
        "$mod, V, exec, walker --provider clipboard --placeholder clipboard"
        "$mod SHIFT, V, exec, ${./menus/clear-clipboard}"

        # quick launch
        "$mod, Return, exec, ghostty"
        "$mod SHIFT, Return, exec, ghostty --title=floating-nvim -e nvim ~/notes/scratch/$(date +%Y%m%d-%H%M%S).md"
        "$mod, B, exec, zen-beta"
        "$mod, C, exec, google-chrome-stable"

        # color picker
        "$mod, P, exec, hyprpicker -a -f hex"

        # voice typing
        "$mod, T, exec, dictator toggle"
        ", F3, exec, dictator cancel"
        "$mod SHIFT, T, exec, dictator transcript last --clip"

        # window management
        "$mod SHIFT, Q, hy3:killactive"
        "$mod, H, hy3:movefocus, l"
        "$mod, J, hy3:movefocus, d"
        "$mod, K, hy3:movefocus, u"
        "$mod, L, hy3:movefocus, r"
        "$mod SHIFT, H, hy3:movewindow, l"
        "$mod SHIFT, J, hy3:movewindow, d"
        "$mod SHIFT, K, hy3:movewindow, u"
        "$mod SHIFT, L, hy3:movewindow, r"

        "$mod, minus, hy3:makegroup, v"
        "$mod, S, hy3:makegroup, tab"
        "$mod, W, hy3:changegroup, toggletab" # toggle current group to/from tabbed
        "$mod, E, hy3:changegroup, opposite" # toggle split orientation (h <-> v)

        "$mod, Escape, workspace, previous"

        "$mod, bracketleft, cyclenext"
        "$mod, bracketright, cyclenext, prev"

        "$mod, F, fullscreen, 0"
        "$mod SHIFT, space, togglefloating"
        "$mod, space, hy3:togglefocuslayer"
        "$mod, P, hy3:changefocus, raise" # focus parent container
        "$mod, C, hy3:changefocus, lower" # focus child container
        "$mod SHIFT, R, exec, hyprctl reload"

        # resize mode
        "$mod, R, submap, resize"

        # move workspace to monitor
        "$mod CTRL, H, movecurrentworkspacetomonitor, l"
        "$mod CTRL, J, movecurrentworkspacetomonitor, d"
        "$mod CTRL, K, movecurrentworkspacetomonitor, u"
        "$mod CTRL, L, movecurrentworkspacetomonitor, r"

        # media keys
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPause, exec, playerctl play-pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"
        ", XF86AudioRaiseVolume, exec, $HOME/dotfiles/bin/volctl +5"
        ", XF86AudioLowerVolume, exec, $HOME/dotfiles/bin/volctl -5"
        ", XF86AudioMute, exec, $HOME/dotfiles/bin/volctl mute"
        ", XF86AudioMicMute, exec, $HOME/dotfiles/bin/volctl mute-mic"
        ", XF86MonBrightnessUp, exec, $HOME/dotfiles/bin/brightctl +5"
        ", XF86MonBrightnessDown, exec, $HOME/dotfiles/bin/brightctl -5"

        # screenshots
        "SHIFT, Print, exec, hyprshot -m output -o $HOME/media/screenshots -f $(date +%Y.%m.%d-%H.%M.%S).png"
        ", Print, exec, hyprshot -m region -o $HOME/media/screenshots -f $(date +%Y.%m.%d-%H.%M.%S).png"

        # workspaces
        "$mod, 0, workspace, name:0"
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"

        # move to workspace
        "$mod SHIFT, 0, movetoworkspace, name:0"
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
      ];

      # mouse bindings (use standard dispatchers for mouse drag)
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
    };

    # resize submap
    extraConfig = ''
      submap = resize
      binde = , n, resizeactive, -20 0
      binde = , t, resizeactive, 0 20
      binde = , s, resizeactive, 0 -20
      binde = , w, resizeactive, 20 0
      bind = , Return, submap, reset
      bind = , Escape, submap, reset
      bind = $mod, R, submap, reset
      submap = reset
    '';
  };
}
