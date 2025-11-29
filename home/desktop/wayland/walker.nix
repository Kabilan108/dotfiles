{
  pkgs,
  theme,
  inputs,
  ...
}:
let
  palette = theme.palette;
  themeName = theme.name;
in
{
  imports = [ inputs.walker.homeManagerModules.default ];

  programs.walker = {
    enable = true;
    runAsService = true;
    package = inputs.walker.packages.${pkgs.system}.default;

    config = {
      columns.symbols = 1;

      theme = themeName;
      force_keyboard_focus = true;
      close_when_open = true;
      click_to_close = true;
      selection_wrap = false;
      hide_action_hints = false;
      hide_action_hints_dmenu = true;

      placeholders.default = {
        input = "Search";
        list = "No results";
      };

      providers = {
        default = [
          "desktopapplications"
          "calc"
          "runner"
          "websearch"
        ];
        empty = [ "desktopapplications" ];
        max_results = 100;
        prefixes = [
          {
            provider = "providerlist";
            prefix = ";";
          }
          {
            provider = "runner";
            prefix = ">";
          }
          {
            provider = "files";
            prefix = "/";
          }
          {
            provider = "symbols";
            prefix = ".";
          }
          {
            provider = "websearch";
            prefix = "@";
          }
          {
            provider = "clipboard";
            prefix = ":";
          }
          {
            provider = "windows";
            prefix = "$";
          }
        ];
        sets = {
          combi = {
            default = [
              "desktopapplications"
              "calc"
              "websearch"
            ];
            empty = [ "desktopapplications" ];
          };
        };
      };
    };

    themes.${themeName} = {
      style = ''
        @define-color window_bg #${palette.base00};
        @define-color surface alpha(#${palette.base01}, 0.95);
        @define-color overlay alpha(#${palette.base02}, 0.60);
        @define-color accent #${palette.base0D};
        @define-color accent_alt #${palette.base0E};
        @define-color accent_bright #${palette.base0C};
        @define-color text #${palette.base05};
        @define-color muted #${palette.base04};
        @define-color border alpha(#${palette.base0D}, 0.75);
        @define-color error #${palette.base08};

        * {
          all: unset;
          color: @text;
          font-family: "FiraMono Nerd Font";
        }

        popover {
          background: lighter(@window_bg);
          border: 2px solid alpha(@border, 0.75);
          border-radius: 14px;
          padding: 10px;
        }

        .box-wrapper {
          background: @window_bg;
          border-radius: 14px;
          border: 2px solid @border;
          padding: 16px;
          min-width: 250px;
          max-width: 800px;
          margin: 0 auto;
        }

        .search-container {
          border-radius: 12px;
          background: alpha(@surface, 0.75);
        }

        .input {
          background: alpha(@surface, 0.9);
          padding: 12px 14px;
          border-radius: 10px;
          caret-color: @accent;
          color: @text;
          font-weight: 600;
        }

        .input placeholder {
          color: @muted;
          opacity: 0.82;
        }

        .list {
          margin-top: 12px;
          color: @text;
        }

        .item-box {
          padding: 10px 12px;
          border-radius: 10px;
          background: transparent;
          transition: background 120ms ease;
          font-weight: 600;
        }

        child:selected .item-box {
          background: alpha(@accent, 0.22);
          box-shadow: none;
          border: 2px solid alpha(@border, 0.75);
        }

        .item-text {
          color: @text;
          font-weight: 600;
        }

        child:selected .item-text {
          color: @accent_alt;
        }

        .item-subtext {
          color: @muted;
          font-size: 12px;
          font-weight: 600;
        }

        .item-quick-activation {
          background: alpha(@accent, 0.18);
          border-radius: 8px;
          padding: 6px 10px;
        }

        .preview {
          background: alpha(@surface, 0.85);
          border: 2px solid alpha(@border, 0.6);
          border-radius: 12px;
          padding: 10px;
          color: @text;
        }

        .keybinds {
          padding-top: 10px;
          margin-top: 8px;
          border-top: 1px solid alpha(@overlay, 0.4);
          color: @muted;
          font-size: 12px;
        }

        .keybind-label {
          border: 1px solid alpha(@border, 0.6);
          border-radius: 6px;
          padding: 2px 6px;
          color: @text;
          font-weight: 600;
        }

        .keybind-bind {
          opacity: 0.6;
          text-transform: lowercase;
        }

        .placeholder {
          color: @muted;
          font-weight: 600;
        }

        .item-image,
        .item-icon {
          color: @accent_bright;
        }

        .error {
          padding: 10px;
          background: alpha(@error, 0.15);
          border-radius: 8px;
          border: 1px solid alpha(@error, 0.5);
        }
      '';

      layouts = {
        "layout" = ''
          <?xml version="1.0" encoding="UTF-8"?>
          <interface>
            <requires lib="gtk" version="4.0"></requires>
            <object class="GtkWindow" id="Window">
              <style>
                <class name="window"></class>
              </style>
              <property name="resizable">true</property>
              <property name="title">Walker</property>
              <child>
                <object class="GtkBox" id="BoxWrapper">
                  <style>
                    <class name="box-wrapper"></class>
                  </style>
                  <property name="overflow">hidden</property>
                  <property name="orientation">horizontal</property>
                  <property name="valign">center</property>
                  <property name="halign">center</property>
                  <property name="height-request">570</property>
                  <child>
                    <object class="GtkBox" id="Box">
                      <style>
                        <class name="box"></class>
                      </style>
                      <property name="orientation">vertical</property>
                      <property name="hexpand-set">true</property>
                      <property name="hexpand">true</property>
                      <property name="spacing">10</property>
                      <child>
                        <object class="GtkBox" id="SearchContainer">
                          <style>
                            <class name="search-container"></class>
                          </style>
                          <property name="overflow">hidden</property>
                          <property name="orientation">horizontal</property>
                          <property name="halign">fill</property>
                          <property name="hexpand-set">true</property>
                          <property name="hexpand">true</property>
                          <child>
                            <object class="GtkEntry" id="Input">
                              <style>
                                <class name="input"></class>
                              </style>
                              <property name="halign">fill</property>
                              <property name="hexpand-set">true</property>
                              <property name="hexpand">true</property>
                            </object>
                          </child>
                        </object>
                      </child>
                      <child>
                        <object class="GtkBox" id="ContentContainer">
                          <style>
                            <class name="content-container"></class>
                          </style>
                          <property name="orientation">horizontal</property>
                          <property name="spacing">10</property>
                          <child>
                            <object class="GtkLabel" id="ElephantHint">
                              <style>
                                <class name="elephant-hint"></class>
                              </style>
                              <property name="label">Waiting for elephant...</property>
                              <property name="hexpand">true</property>
                              <property name="vexpand">true</property>
                              <property name="visible">false</property>
                              <property name="valign">0.5</property>
                            </object>
                          </child>
                          <child>
                            <object class="GtkLabel" id="Placeholder">
                              <style>
                                <class name="placeholder"></class>
                              </style>
                              <property name="label">No Results</property>
                              <property name="hexpand">true</property>
                              <property name="vexpand">true</property>
                              <property name="valign">0.5</property>
                            </object>
                          </child>
                          <child>
                            <object class="GtkScrolledWindow" id="Scroll">
                              <style>
                                <class name="scroll"></class>
                              </style>
                              <property name="can_focus">false</property>
                              <property name="overlay-scrolling">true</property>
                              <property name="hexpand">true</property>
                              <property name="vexpand">true</property>
                              <property name="max-content-width">800</property>
                              <property name="min-content-width">200</property>
                              <property name="max-content-height">400</property>
                              <property name="propagate-natural-height">true</property>
                              <property name="propagate-natural-width">true</property>
                              <property name="hscrollbar-policy">automatic</property>
                              <property name="vscrollbar-policy">automatic</property>
                              <child>
                                <object class="GtkGridView" id="List">
                                  <style>
                                    <class name="list"></class>
                                  </style>
                                  <property name="max_columns">1</property>
                                  <property name="min_columns">1</property>
                                  <property name="can_focus">false</property>
                                </object>
                              </child>
                            </object>
                          </child>
                          <child>
                            <object class="GtkBox" id="Preview">
                              <style>
                                <class name="preview"></class>
                              </style>
                            </object>
                          </child>
                        </object>
                      </child>
                      <child>
                        <object class="GtkBox" id="Keybinds">
                          <property name="hexpand">true</property>
                          <property name="margin-top">10</property>
                          <style>
                            <class name="keybinds"></class>
                          </style>
                          <child>
                            <object class="GtkBox" id="GlobalKeybinds">
                              <property name="spacing">10</property>
                              <style>
                                <class name="global-keybinds"></class>
                              </style>
                            </object>
                          </child>
                          <child>
                            <object class="GtkBox" id="ItemKeybinds">
                              <property name="hexpand">true</property>
                              <property name="halign">end</property>
                              <property name="spacing">10</property>
                              <style>
                                <class name="item-keybinds"></class>
                              </style>
                            </object>
                          </child>
                        </object>
                      </child>
                      <child>
                        <object class="GtkLabel" id="Error">
                          <style>
                            <class name="error"></class>
                          </style>
                          <property name="xalign">0</property>
                          <property name="visible">false</property>
                        </object>
                      </child>
                    </object>
                  </child>
                </object>
              </child>
            </object>
          </interface>
        '';
      };
    };

    elephant = {
      providers = [
        "desktopapplications"
        "runner"
        "calc"
        "websearch"
        "clipboard"
        "windows"
        "symbols"
        "files"
        "menus"
      ];

      settings = {
        auto_detect_launch_prefix = false;
      };

      provider.websearch.settings = {
        command = "zen-beta";
        engines_as_actions = false;
        entries = [
          {
            name = "Unduck";
            default = true;
            url = "https://unduck.link?q=%TERM%";
            icon = "web-browser";
          }
        ];
      };

      provider.clipboard.settings = {
        max_items = 200;
        ignore_symbols = false;
        auto_cleanup = 0;
      };

      provider.menus.toml.power = {
        name = "power";
        name_pretty = "Power";
        icon = "system-shutdown";
        action = "%VALUE%";
        placeholders.default = {
          input = "power";
          list = "No results";
        };
        entries = [
          {
            text = "Lock";
            value = "hyprlock";
            icon = "system-lock-screen";
            keywords = [
              "lock"
              "sleep"
            ];
          }
          {
            text = "Suspend";
            value = "systemctl suspend";
            icon = "system-suspend";
            keywords = [
              "sleep"
              "suspend"
            ];
          }
          {
            text = "Logout";
            value = "bash -lc 'systemctl --user stop waybar.service walker.service; hyprctl dispatch exit'";
            icon = "system-log-out";
            keywords = [
              "logout"
              "quit"
            ];
          }
          {
            text = "Reboot";
            value = "systemctl reboot";
            icon = "system-reboot";
            keywords = [
              "reboot"
              "restart"
            ];
          }
          {
            text = "Shutdown";
            value = "systemctl poweroff";
            icon = "system-shutdown";
            keywords = [
              "shutdown"
              "poweroff"
            ];
          }
        ];
      };
    };
  };
}
