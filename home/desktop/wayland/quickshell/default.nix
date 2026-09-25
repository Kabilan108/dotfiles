{
  pkgs,
  config,
  inputs,
  lib,
  ...
}:
let
  homeDir = "/home/kabilan";
  fleet = import ../../../../lib/fleet.nix;
  dictatorPackages = inputs.dictator.packages.${pkgs.stdenv.hostPlatform.system};
  builtinPlugin = name: {
    source = ../../../../packages/stillsuit-shell/src;
    manifestFile = "plugins/builtin/${name}/manifest.json";
  };
  meetingEnqueueHelper =
    pkgs.callPackage ../../../../packages/stillsuit-shell/meeting-enqueue-helper.nix
      { };
  recorderHelper = pkgs.callPackage ../../../../packages/stillsuit-shell/recorder-helper.nix {
    inherit meetingEnqueueHelper;
    omarecord = inputs.omarecord.packages.${pkgs.stdenv.hostPlatform.system}.omarecord;
  };
  networkHelper = pkgs.callPackage ../../../../packages/stillsuit-shell/network-helper.nix { };
  agentUsageHelper = pkgs.callPackage ../../../../packages/stillsuit-shell/agent-usage-helper.nix { };
  publishHelper = pkgs.writeShellApplication {
    name = "stillsuit-publish";
    runtimeInputs = [ inputs.pagebin.packages.${pkgs.stdenv.hostPlatform.system}.default ];
    text = ''
      exec pagebin publish --json --no-infer "$1"
    '';
  };
  openHelper = pkgs.writeShellApplication {
    name = "stillsuit-open";
    runtimeInputs = [
      pkgs.glib
      pkgs.mpv
      pkgs.nautilus
    ];
    # gio launches the handler's Exec line (e.g. a bare `helium`), which the
    # shell unit's restricted PATH cannot resolve on its own.
    text = ''
      export PATH="$PATH:/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin"
      gio open -- "$1"
    '';
  };
  # The key's authorized_keys entry on sietch forces `moberg-dev-status`, so
  # this can only ever read `dev co list --json`.
  devCheckoutsHelper = pkgs.writeShellApplication {
    name = "stillsuit-dev-checkouts";
    runtimeInputs = [ pkgs.openssh ];
    text = ''
      exec ssh -i "$HOME/.ssh/moberg-status-jacurutu" \
        -o IdentitiesOnly=yes -o BatchMode=yes -o ControlMaster=no -o ControlPath=none \
        -o ConnectTimeout=5 -o ServerAliveInterval=5 -o ServerAliveCountMax=2 \
        ${fleet.hosts.sietch.user}@${fleet.hosts.sietch.tailscaleIp} moberg-dev-status
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

  # Stillsuit is built on niri IPC. Hosts that also run Hyprland reach
  # graphical-session.target from both compositors, so skip the Hyprland one.
  systemd.user.services.stillsuit-shell.Unit.ConditionEnvironment = "XDG_CURRENT_DESKTOP=niri";

  # Stillsuit provides the network and Bluetooth controls. Keep the desktop
  # packages available for their manager commands, but suppress their legacy
  # XDG tray applets.
  xdg.configFile."autostart/nm-applet.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Hidden=true
  '';
  xdg.configFile."autostart/blueman.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Hidden=true
  '';

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
    # Enabled by the "moberg" Stillsuit profile.
    (
      (builtinPlugin "dev-checkouts")
      // {
        enable = false;
        settings = {
          helperPath = lib.getExe devCheckoutsHelper;
          openHelperPath = lib.getExe openHelper;
        };
      }
    )
    ((builtinPlugin "moberg-demo") // { enable = false; })
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
    (
      if config.dotfiles.services.dictator.enable then
        (builtinPlugin "dictation")
        // {
          settings = {
            dictatorCliPath = "${dictatorPackages.default}/bin/dictator";
            dictatorGuiPath = "${dictatorPackages.gui}/bin/dictator-gui";
            recentLimit = 5;
          };
        }
      else
        (builtinPlugin "dictation") // { enable = false; }
    )
    (builtinPlugin "recording")
    (builtinPlugin "resources")
    (builtinPlugin "tray")
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
          publishHelperPath = lib.getExe publishHelper;
          dictatorSocketPath = "/run/user/1000/dictator/osd.sock";
        };
      }
    )
  ];
}
