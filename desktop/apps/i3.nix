{ theme, ... }:
let
  mod = "Mod4";
  palette = theme.palette;
in
{
  xsession.windowManager.i3 = {
    enable = true;
    config = {
      modifier = mod;

      bars = [ ];
      fonts = {
        names = [ "FiraMono Nerd Font" ];
        size = 11.0;
      };

      floating.modifier = mod;
      floating.border = 2;

      gaps.inner = 2;
      gaps.outer = 2;

      modes = {
        resize = {
          "n" = "resize shrink width 10 px or 10 ppt"; # narrower
          "t" = "resize grow height 10 px or 10 ppt"; # taller
          "s" = "resize shrink height 10 px or 10 ppt"; # shorter
          "w" = "resize grow width 10 px or 10 ppt"; # wider
          "Return" = "mode default";
          "Escape" = "mode default";
          "${mod}+r" = "mode default";
        };
      };

      window.border = 2;
      window.commands = [
        {
          criteria.class = "Evolution-alarm-notify";
          command = "floating enable, resize set 600 300, move position center";
        }
        {
          criteria.class = ".blueman-manager-wrapped";
          command = "floating enable, resize set 400 300, move position center";
        }
        {
          criteria.class = "Org.gnome.Nautilus";
          command = "floating enable, resize set 800 600";
        }
        {
          criteria.class = "org.gnome.Nautilus";
          command = "floating enable, resize set 800 600";
        }
        {
          criteria.class = "TelegramDesktop";
          command = "floating enable, resize set 800 600";
        }
        {
          criteria.class = "Dictator-dev-linux-amd64";
          command = "floating enable";
        }
        {
          criteria.class = "zoom";
          command = "floating enable, resize set 800 600";
        }
        {
          criteria.class = "pavucontrol";
          command = "floating enable";
        }
        {
          criteria.class = "Dictator";
          command = "floating enable";
        }
        {
          criteria.class = "steam";
          command = "floating enable, resize set 800 600";
        }
        {
          criteria.class = "Spotify";
          command = "move workspace 9";
        }
        {
          criteria.class = "obsidian";
          command = "move workspace 2";
        }
        {
          criteria.class = "Slack";
          command = "move workspace 2";
        }
        {
          criteria.class = "^.*";
          command = "border pixel 2";
        }
      ];

      startup = [
        {
          command = "autorandr --change";
          always = true;
        }
        {
          command = "dunst";
          notification = false;
        }
        {
          command = "nm-applet";
          notification = false;
        }
        {
          command = "obsidian";
          notification = false;
        }
        {
          command = "picom --config $HOME/.config/picom/picom.conf -b";
          notification = false;
        }
        {
          command = "sleep 2 && blueman-applet";
          notification = false;
        }
        {
          command = "setxkbmap -option caps:escape";
          notification = false;
          always = true;
        }
        {
          command = "${../../dev/bin/set-wallpaper}";
          notification = false;
          always = true;
        }
        {
          command = "${../../dev/bin/start-polybar}";
          notification = false;
          always = true;
        }
        {
          command = "${../../dev/bin/battery-watcher}";
          notification = false;
        }
      ];

      colors = {
        background = "#${palette.base00}"; # base

        focused = {
          border = "#${palette.base01}"; # mantle
          background = "#${palette.base01}"; # mantle
          text = "#${palette.base0E}"; # mauve
          indicator = "#${palette.base07}"; # lavender
          childBorder = "#${palette.base07}"; # lavender
        };
        focusedInactive = {
          border = "#${palette.base02}"; # surface0
          background = "#${palette.base01}"; # mantle
          text = "#${palette.base05}"; # text
          indicator = "#${palette.base03}"; # surface1
          childBorder = "#${palette.base03}"; # surface1
        };
        unfocused = {
          border = "#${palette.base03}"; # surface1
          background = "#${palette.base02}"; # text
          text = "#${palette.base06}"; # rosewater
          indicator = "#${palette.base04}"; # surface2
          childBorder = "#${palette.base04}"; # surface2
        };
        urgent = {
          border = "#${palette.base09}"; # peach
          background = "#${palette.base09}"; # peach
          text = "#${palette.base00}"; # base
          indicator = "#${palette.base08}"; # red
          childBorder = "#${palette.base08}"; # red
        };
      };

      # take screenshots
      keycodebindings."107" =
        "exec flameshot gui --clipboard --path $HOME/media/screenshots/$(date +%Y.%m.%d-%H.%M.%S).png";

      keybindings = {
        # rofi menus
        "${mod}+d" = "exec --no-startup-id rofi -show drun";
        "${mod}+Shift+d" = "exec --no-startup-id rofi -show combi";
        "${mod}+Tab" = "exec --no-startup-id rofi -show window";
        "${mod}+u" = "exec --no-startup-id $HOME/.config/rofi/menus/web-search";
        "${mod}+Shift+e" = "exec --no-startup-id $HOME/.config/rofi/menus/exit";
        "${mod}+v" = "exec --no-startup-id $HOME/.config/rofi/menus/clippy";
        "${mod}+Shift+v" = "exec --no-startup-id $HOME/.config/rofi/menus/clippy clear";

        # quickstart
        "${mod}+Return" = "exec ghostty";

        # voice typing
        "${mod}+t" = "exec dictator toggle";
        "F3" = "exec dictator cancel";
        "${mod}+Shift+t" = "exec dictator transcript last --clip";

        # window management
        "${mod}+Shift+q" = "kill";
        "${mod}+h" = "focus left";
        "${mod}+j" = "focus down";
        "${mod}+k" = "focus up";
        "${mod}+l" = "focus right";
        "${mod}+Shift+h" = "move left";
        "${mod}+Shift+j" = "move down";
        "${mod}+Shift+k" = "move up";
        "${mod}+Shift+l" = "move right";
        "${mod}+bar" = "split h";
        "${mod}+minus" = "split v";
        "${mod}+f" = "fullscreen toggle";
        "${mod}+s" = "layout stacking";
        "${mod}+w" = "layout tabbed";
        "${mod}+e" = "layout toggle split";
        "${mod}+Shift+space" = "floating toggle";
        "${mod}+space" = "focus mode_toggle";
        "${mod}+p" = "focus parent";
        "${mod}+c" = "focus child";
        "${mod}+Shift+c" = "reload";
        "${mod}+Shift+r" = "restart";

        "${mod}+r" = "mode resize";
        "${mod}+z" = "gaps outer current plus 5";
        "${mod}+Shift+z" = "gaps outer current minus 5";
        "${mod}+x" = "gaps inner current plus 5";
        "${mod}+Shift+x" = "gaps inner current minus 5";

        "${mod}+Ctrl+h" = "move workspace to output left";
        "${mod}+Ctrl+j" = "move workspace to output down";
        "${mod}+Ctrl+k" = "move workspace to output up";
        "${mod}+Ctrl+l" = "move workspace to output right";

        "XF86AudioPlay" = "exec playerctl play-pause";
        "XF86AudioPause" = "exec playerctl play-pause";
        "XF86AudioNext" = "exec playerctl next";
        "XF86AudioPrev" = "exec playerctl previous";
        "XF86AudioRaiseVolume" = "exec --no-startup-id ${../../dev/bin/volctl} +5";
        "XF86AudioLowerVolume" = "exec --no-startup-id ${../../dev/bin/volctl} -5";
        "XF86AudioMute" = "exec --no-startup-id ${../../dev/bin/volctl} mute";
        "XF86AudioMicMute" = "exec --no-startup-id ${../../dev/bin/volctl} mute-mic";
        "XF86MonBrightnessUp" = "exec --no-startup-id ${../../dev/bin/brightctl} +5";
        "XF86MonBrightnessDown" = "exec --no-startup-id ${../../dev/bin/brightctl} -5";

        # switch to workspace
        "${mod}+0" = "workspace number 0";
        "${mod}+1" = "workspace number 1";
        "${mod}+2" = "workspace number 2";
        "${mod}+3" = "workspace number 3";
        "${mod}+4" = "workspace number 4";
        "${mod}+5" = "workspace number 5";
        "${mod}+6" = "workspace number 6";
        "${mod}+7" = "workspace number 7";
        "${mod}+8" = "workspace number 8";
        "${mod}+9" = "workspace number 9";

        # move to workspace
        "${mod}+Shift+0" = "move container to workspace number 0";
        "${mod}+Shift+1" = "move container to workspace number 1";
        "${mod}+Shift+2" = "move container to workspace number 2";
        "${mod}+Shift+3" = "move container to workspace number 3";
        "${mod}+Shift+4" = "move container to workspace number 4";
        "${mod}+Shift+5" = "move container to workspace number 5";
        "${mod}+Shift+6" = "move container to workspace number 6";
        "${mod}+Shift+7" = "move container to workspace number 7";
        "${mod}+Shift+8" = "move container to workspace number 8";
        "${mod}+Shift+9" = "move container to workspace number 9";
      };
    };

    extraConfig = ''
      default_border pixel 2
      default_floating_border pixel 2
    '';
  };
}
