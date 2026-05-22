{
  config,
  waylandCompositor,
  ...
}:
let
  colors = config.lib.stylix.colors.withHashtag;
  workspaceModule = if waylandCompositor == "niri" then "niri/workspaces" else "hyprland/workspaces";
  workspaceFormat = if waylandCompositor == "niri" then "{value}" else "{name}";
in
{
  programs.waybar = {
    enable = true;
    systemd.enable = true;

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 28;
        margin = "0";
        spacing = 0;

        modules-left = [
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
        background: alpha(${colors.base00}, 0.95);
        color: ${colors.base05};
        padding: 2px 8px;
        border-radius: 0;
        border: none;
      }

      #workspaces {
        margin-left: 8px;
      }

      #workspaces button {
        padding: 0px;
        margin: 4px 2px;
        color: ${colors.base04};
        background: transparent;
        border-radius: 2px;
      }

      #workspaces button.active {
        color: ${colors.base0C};
        background: alpha(${colors.base0C}, 0.25);
      }

      #workspaces button:hover {
        background: alpha(${colors.base01}, 0.85);
      }

      #workspaces button.urgent {
        color: ${colors.base08};
        background: alpha(${colors.base01}, 0.85);
      }

      #clock {
        color: ${colors.base05};
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
        color: ${colors.base0C};
      }

      #memory {
        color: ${colors.base05};
      }

      #cpu {
        color: ${colors.base0A};
      }

      #battery {
        color: ${colors.base05};
        margin-right: 8px;
      }

      #battery.charging {
        color: ${colors.base0B};
      }

      #battery.warning {
        color: ${colors.base09};
      }

      #battery.critical {
        color: ${colors.base08};
      }

      tooltip {
        background: ${colors.base00};
        color: ${colors.base05};
        border: 1px solid ${colors.base0D};
        border-radius: 6px;
      }
    '';
  };
}
