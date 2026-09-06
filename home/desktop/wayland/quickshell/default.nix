{
  pkgs,
  config,
  lib,
  ...
}:
let
  homeDir = "/home/kabilan";
  builtinPlugin = name: {
    source = ../../../../packages/stillsuit-shell/src;
    manifestFile = "plugins/builtin/${name}/manifest.json";
  };
  meetingEnqueueHelper =
    pkgs.callPackage ../../../../packages/stillsuit-shell/meeting-enqueue-helper.nix
      { };
  recorderHelper = pkgs.callPackage ../../../../packages/stillsuit-shell/recorder-helper.nix {
    inherit meetingEnqueueHelper;
  };
  networkHelper = pkgs.callPackage ../../../../packages/stillsuit-shell/network-helper.nix { };
  agentUsageHelper = pkgs.callPackage ../../../../packages/stillsuit-shell/agent-usage-helper.nix { };
  openHelper = pkgs.writeShellApplication {
    name = "stillsuit-open";
    runtimeInputs = [
      pkgs.glib
      pkgs.mpv
      pkgs.nautilus
    ];
    text = ''
      gio open -- "$1"
    '';
  };
in
{
  programs.stillsuitShell.enable = true;
  programs.stillsuitShell.pluginRoots = [
    "${homeDir}/dotfiles/packages/stillsuit-shell/src/plugins/builtin"
    "${config.xdg.configHome}/stillsuit/plugins"
  ];
  programs.stillsuitShell.ownership.barOwners = [ "stillsuit.builtin-bar" ];
  programs.stillsuitShell.workbench.enable = true;
  programs.stillsuitShell.ownership.notificationOwners = [ "stillsuit.notifications" ];
  home.packages = [ pkgs.quickshell ];

  programs.stillsuitShell.integrations.agentPanelHelperPackage =
    pkgs.callPackage ../../../../packages/stillsuit-shell/agent-panel-helper.nix
      { };

  programs.stillsuitShell.runtimeInputs = [
    pkgs.blueman
    pkgs.niri
    pkgs.pavucontrol
    pkgs.pulseaudio
    pkgs.power-profiles-daemon
    pkgs.upower
    agentUsageHelper
    networkHelper
  ];

  programs.stillsuitShell.plugins = [
    (builtinPlugin "agent-panel")
    (
      (builtinPlugin "agent-usage")
      // {
        settings = {
          helperPath = lib.getExe agentUsageHelper;
          inherit homeDir;
          shadowRoot = "${homeDir}/.shadow-home-dirs";
          includeDefaults = true;
          refreshIntervalSec = 300;
          accounts = [ ];
        };
      }
    )
    ((builtinPlugin "audio") // { settings.managerPath = lib.getExe pkgs.pavucontrol; })
    (
      (builtinPlugin "bar")
      // {
        settings.shadowMode = config.programs.stillsuitShell.development.shadowMode;
      }
    )
    (builtinPlugin "battery")
    (
      (builtinPlugin "bluetooth")
      // {
        settings.managerPath = lib.getExe' pkgs.blueman "blueman-manager";
      }
    )
    (builtinPlugin "clock")
    (
      (builtinPlugin "network")
      // {
        settings.networkHelperPath = lib.getExe networkHelper;
      }
    )
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
          meetingJobsPath = "${homeDir}/.local/state/meeting-minutes/jobs.json";
          meetingHelperPath = lib.getExe meetingEnqueueHelper;
          openHelperPath = lib.getExe openHelper;
          dictatorSocketPath = "/run/user/1000/dictator/osd.sock";
        };
      }
    )
  ];
}
