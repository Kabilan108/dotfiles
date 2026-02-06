{
  theme,
  waylandCompositor,
  ...
}:
let
  palette = theme.palette;
  workspaceModule =
    if waylandCompositor == "niri" then
      "niri/workspaces"
    else
      "hyprland/workspaces";
  workspaceFormat =
    if waylandCompositor == "niri" then
      "{value}"
    else
      "{name}";
in
{
  programs.waybar = {
    enable = true;
    systemd.enable = true;

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 34;
        margin = "0";
        spacing = 0;

        modules-left = [
          "custom/menu"
          workspaceModule
        ];
        modules-center = [ "clock" ];
        modules-right = [
          "tray"
          "pulseaudio"
          "memory"
          "cpu"
          "battery"
        ];

        "custom/menu" = {
          format = "󱄅";
          on-click = "walker --provider desktopapplications";
          on-click-right = "walker --provider menus:power";
          tooltip = false;
        };

        "${workspaceModule}" = {
          format = workspaceFormat;
          on-click = "activate";
          sort-by-number = false;
          sort-by = "id";
        };

        clock = {
          format = "{:%m-%d-%Y %H:%M:%S}";
          interval = 1;
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };

        pulseaudio = {
          format = "{icon}  {volume}%";
          format-muted = "󰖁 ";
          format-icons = {
            default = [
              "󰕿"
              "󰖀"
              "󰕾"
            ];
          };
          on-click = "pavucontrol";
        };

        memory = {
          format = "  {percentage}%";
          interval = 2;
        };

        cpu = {
          format = "  {usage}%";
          interval = 2;
        };

        battery = {
          format = "{icon} {capacity}%";
          format-charging = "󰂇 {capacity}%";
          format-icons = [
            "󰁺"
            "󰁻"
            "󰁼"
            "󰁽"
            "󰁾"
            "󰁿"
            "󰂀"
            "󰂁"
            "󰂂"
            "󰁹"
          ];
          states = {
            warning = 20;
            critical = 10;
          };
        };

        tray = {
          icon-size = 16;
          spacing = 8;
        };
      };
    };

    style = ''
      * {
        font-family: "FiraMono Nerd Font";
        font-size: 15px;
        border: none;
        border-radius: 0;
        min-height: 0;
      }

      window#waybar {
        background: alpha(#${palette.base00}, 0.95);
        color: #${palette.base05};
        padding: 2px 8px;
        border-radius: 0;
        border: none;
      }

      #workspaces button {
        padding: 1px 2px;
        margin: 4px 2px;
        color: #${palette.base04};
        background: transparent;
        border-radius: 3px;
      }

      #workspaces button.active {
        color: #${palette.base0C};
        background: alpha(#${palette.base0C}, 0.25);
      }

      #workspaces button:hover {
        background: alpha(#${palette.base0C}, 0.1);
      }

      #workspaces button.urgent {
        color: #${palette.base08};
      }

      #custom-menu {
        color: #${palette.base0D};
        padding: 0;
        margin: 0 15px 0 10px;
        font-size: 20px;
      }

      #clock {
        color: #${palette.base05};
        font-weight: 500;
      }

      #pulseaudio,
      #memory,
      #cpu,
      #battery {
        padding: 0 8px;
      }

      #tray {
        padding: 0 4px;
      }

      #pulseaudio {
        color: #${palette.base0C};
      }

      #memory {
        color: #${palette.base07};
      }

      #cpu {
        color: #${palette.base0A};
      }

      #battery {
        color: #${palette.base07};
      }

      #battery.charging {
        color: #${palette.base0B};
      }

      #battery.warning {
        color: #${palette.base09};
      }

      #battery.critical {
        color: #${palette.base08};
      }

      tooltip {
        background: #${palette.base00};
        border: 1px solid #${palette.base02};
        border-radius: 6px;
      }
    '';
  };
}
