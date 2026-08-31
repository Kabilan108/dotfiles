{
  pkgs,
  config,
  lib,
  ...
}:
let
  homeDir = "/home/kabilan";
  colors = config.lib.stylix.colors.withHashtag;
  fontSans = config.stylix.fonts.sansSerif.name or "Noto Sans";
  fontMono = config.stylix.fonts.monospace.name or "FiraMono Nerd Font";
  transparent = alpha: color: "#${alpha}${lib.removePrefix "#" color}";
  builtinPlugin = name: {
    source = ../../../../packages/stillsuit-shell/src;
    manifestFile = "plugins/builtin/${name}/manifest.json";
  };
  recorderHelper = pkgs.callPackage ../../../../packages/stillsuit-shell/recorder-helper.nix {
    meetingMinutesPath = "${homeDir}/bin/meeting-minutes";
  };
in
{
  home.packages = [ pkgs.quickshell ];

  programs.stillsuitShell.integrations.agentPanelHelperPackage =
    pkgs.callPackage ../../../../packages/stillsuit-shell/agent-panel-helper.nix
      { };

  programs.stillsuitShell.runtimeInputs = [
    pkgs.niri
    pkgs.power-profiles-daemon
  ];

  programs.stillsuitShell.plugins = [
    (builtinPlugin "agent-panel")
    (builtinPlugin "audio")
    (
      (builtinPlugin "bar")
      // {
        settings.shadowMode = config.programs.stillsuitShell.development.shadowMode;
      }
    )
    (builtinPlugin "battery")
    (builtinPlugin "bluetooth")
    (builtinPlugin "clock")
    (builtinPlugin "meeting")
    (builtinPlugin "network")
    (
      (builtinPlugin "notifications")
      // {
        enable =
          config.programs.stillsuitShell.development.shadowMode
          ||
            config.programs.stillsuitShell.ownership.notificationOwners == [
              "stillsuit.notifications"
            ];
        settings = {
          shadowMode = config.programs.stillsuitShell.development.shadowMode;
          claimNotificationBus =
            config.programs.stillsuitShell.ownership.notificationOwners == [
              "stillsuit.notifications"
            ];
        };
      }
    )
    (
      (builtinPlugin "osd")
      // {
        settings = {
          brightnessMaxPath = "/sys/class/backlight/amdgpu_bl1/max_brightness";
          brightnessPath = "/sys/class/backlight/amdgpu_bl1/brightness";
        };
      }
    )
    (builtinPlugin "power")
    (builtinPlugin "recording")
    (builtinPlugin "resources")
    (builtinPlugin "workspaces")
    (
      (builtinPlugin "workflows")
      // {
        settings = {
          recorderHelperPath = lib.getExe recorderHelper;
          recordingStatePath = "/run/user/1000/stillsuit/recording.json";
          recordingDirectory = "${homeDir}/media/recordings";
          desktopAudioDefault = true;
          microphoneDefault = false;
          meetingStatusPath = "${homeDir}/.local/state/meeting-minutes/status.json";
          openHelperPath = lib.getExe' pkgs.xdg-utils "xdg-open";
          dictatorSocketPath = "/run/user/1000/dictator/osd.sock";
        };
      }
    )
  ];

  xdg.configFile."quickshell/osd".source =
    config.lib.file.mkOutOfStoreSymlink "${homeDir}/dotfiles/home/desktop/wayland/quickshell/osd";

  xdg.configFile."quickshell/stillsuit".source =
    config.lib.file.mkOutOfStoreSymlink "${homeDir}/dotfiles/home/desktop/wayland/quickshell/stillsuit";

  xdg.configFile."quickshell/theme/stylix.json".text = builtins.toJSON {
    palette = {
      crust = colors.base00;
      mantle = colors.base01;
      base = colors.base00;
      surface0 = colors.base02;
      surface1 = colors.base03;
      surface2 = colors.base04;
      overlay0 = colors.base03;
      overlay1 = colors.base04;
      overlay2 = colors.base05;
      subtext0 = colors.base04;
      subtext1 = colors.base05;
      text = colors.base05;
      rosewater = colors.base06;
      flamingo = colors.base0F;
      pink = colors.base0E;
      mauve = colors.base0E;
      red = colors.base08;
      maroon = colors.base08;
      peach = colors.base09;
      yellow = colors.base0A;
      green = colors.base0B;
      teal = colors.base0C;
      sky = colors.base0C;
      sapphire = colors.base0D;
      blue = colors.base0D;
      lavender = colors.base07;
    };
    semantic = {
      panelBg = transparent "d9" colors.base00;
      panelBgSoft = transparent "d9" colors.base00;
      panelBgStrong = transparent "eb" colors.base00;
      panelChrome = transparent "f2" colors.base00;
      panelBorder = transparent "1a" colors.base05;
      panelBorderStrong = colors.base03;
      panelSurface = transparent "b8" colors.base02;
      panelSurfaceHover = transparent "cc" colors.base03;
      panelSurfaceActive = transparent "d9" colors.base04;
      foreground = colors.base05;
      dimText = colors.base04;
      mutedText = colors.base03;
      accent = colors.base0D;
      accent2 = colors.base05;
      bright = colors.base0A;
      vol = colors.base0B;
      mic = colors.base08;
      charge = colors.base09;
      success = colors.base0B;
      warning = colors.base0A;
      urgent = colors.base08;
      info = colors.base0C;
      osdTrack = transparent "1f" colors.base05;
      osdFillMuted = colors.base03;
      shadow = transparent "66" colors.base00;
    };
    typography = {
      fontFamily = fontMono;
      iconFamily = "Material Symbols Rounded";
      bodyFontFamily = fontSans;
      fontSizeSmall = 11;
      fontSizeMedium = 13;
      fontSizeLarge = 16;
      fontSizeTitle = 14;
      fontSizeIcon = 20;
      fontSizeIconLarge = 24;
    };
    geometry = {
      radiusSmall = 5;
      radiusMedium = 5;
      radiusLarge = 5;
      radiusPill = 9999;
      paddingSmall = 8;
      paddingMedium = 14;
      paddingLarge = 20;
      borderWidth = 1;
      panelWidth = 380;
      barHeight = 38;
      osdWidth = 360;
      osdHeight = 58;
      screenMargin = 8;
      panelGap = 8;
    };
    animation = {
      fast = 120;
      medium = 180;
      slow = 260;
      osdHideMs = 1500;
      notificationDefaultMs = 5000;
      notificationLowMs = 4000;
    };
  };

  xdg.configFile."quickshell/stillsuit-policy.json".text = builtins.toJSON {
    recordings = {
      completionTimeoutMs = 8000;
      directory = "${homeDir}/media/recordings";
    };
    notifications = {
      dndBypass = {
        critical = true;
        appNames = [
          "battery"
          "Battery"
        ];
        appUrgencies = [
          {
            appName = "notify-send";
            urgency = "critical";
          }
        ];
        summaryPatterns = [ ];
      };
    };
  };
}
