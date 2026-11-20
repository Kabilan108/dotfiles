{
  pkgs,
  config,
  osConfig,
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
  remminaListHelper =
    pkgs.callPackage ../../../../packages/stillsuit-shell/remmina-list-helper.nix
      { };
  agentUsageHelper = pkgs.callPackage ../../../../packages/stillsuit-shell/agent-usage-helper.nix {
    agyBin = "${homeDir}/.local/bin/agy";
    codexBin = "${homeDir}/.local/bin/codex";
  };
  clipboardCollector =
    pkgs.callPackage ../../../../packages/stillsuit-shell/clipboard-collector.nix
      { };
  niri = lib.getExe osConfig.programs.niri.package;
  lockScreen = lib.findFirst (
    package: (package.name or "") == "lock-screen"
  ) null config.home.packages;
  publishHelper = pkgs.writeShellApplication {
    name = "stillsuit-publish";
    runtimeInputs = [ pkgs.pagebin ];
    text = ''
      exec pagebin publish --json --no-infer "$1"
    '';
  };
  openHelper = pkgs.writeShellApplication {
    name = "stillsuit-open";
    runtimeInputs = [
      pkgs.glib
      pkgs.mpv
    ];
    text = ''
      export PATH="$PATH:/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin"
      gio open -- "$1"
    '';
  };
  devCheckoutsHelper = pkgs.writeShellApplication {
    name = "stillsuit-dev-checkouts";
    runtimeInputs = [ pkgs.openssh ];
    text = ''
      if (($# == 0)); then
        set -- status
      fi
      exec ssh -i "$HOME/.ssh/moberg-status-jacurutu" \
        -o IdentitiesOnly=yes -o BatchMode=yes -o ControlMaster=no -o ControlPath=none \
        -o ConnectTimeout=5 -o ServerAliveInterval=5 -o ServerAliveCountMax=2 \
        ${fleet.hosts.sietch.user}@${fleet.hosts.sietch.tailscaleIp} "$@"
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

  systemd.user.services.stillsuit-shell.Unit.ConditionEnvironment = "XDG_CURRENT_DESKTOP=niri";

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
    clipboardCollector
    networkHelper
    pkgs.wl-clipboard
    pkgs.libqalculate
    pkgs.fd
  ];

  programs.stillsuitShell.launch = {
    terminal = [
      "ghostty"
      "-e"
    ];
    browser = [ "helium" ];
    opener = [ "xdg-open" ];
    session = {
      lock = lib.mkIf (lockScreen != null) [ "${lockScreen}/bin/lock-screen" ];
      logout = [
        niri
        "msg"
        "action"
        "quit"
        "--skip-confirmation"
      ];
    };
  };

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
    (
      (builtinPlugin "clipboard")
      // {
        settings = {
          collectorPath = lib.getExe clipboardCollector;
          wlPastePath = lib.getExe' pkgs.wl-clipboard "wl-paste";
          wlCopyPath = lib.getExe' pkgs.wl-clipboard "wl-copy";
          maxItems = 200;
          ttlHours = 72;
          maxTextBytes = 1048576;
          maxImageBytes = 20971520;
          clearPurgeWindowSec = 330;
          unattributedFirefox = "skip";
          focusSettleMs = 2000;
          geckoAppIds = "^(zen|zen-beta|zen-browser|zen-alpha|zen-twilight|app\\.zen_browser\\.zen|firefox|firefox-esr|firefox-nightly|librewolf|org\\.mozilla\\.firefox)$";
          niriPath = niri;
          secretSourcePrefixes = [ "chrome-extension://aeblfdkhhhdcdjpifhhbdiojplfjncoa/" ];
        };
      }
    )
    (builtinPlugin "clock")
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
    (
      (builtinPlugin "launcher")
      // {
        settings = {
          remminaListPath = lib.getExe remminaListHelper;
          remminaPath = lib.getExe pkgs.remmina;
          qalcPath = lib.getExe' pkgs.libqalculate "qalc";
          fdPath = lib.getExe pkgs.fd;
          searchRoot = homeDir;
          webEngine = "https://unduck.link?q=%TERM%";
          maxResults = 100;
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
          dictatorSocketPath = lib.optionalString config.dotfiles.services.dictator.enable "/run/user/1000/dictator/osd.sock";
        };
      }
    )
  ];
}
