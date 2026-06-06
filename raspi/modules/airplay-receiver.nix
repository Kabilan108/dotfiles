{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.tleilax.airplayReceiver;
  uxplayArgs = [
    "-n"
    cfg.name
    "-nh"
  ]
  ++ lib.optionals cfg.softwareDecode [
    "-avdec"
  ]
  ++ lib.optionals (!cfg.softwareDecode && cfg.hardwareDecode) [
    "-v4l2"
  ]
  ++ lib.optionals cfg.bt709 [
    "-bt709"
  ]
  ++ lib.optionals cfg.hls.enable [
    "-hls"
    (toString cfg.hls.version)
  ]
  ++ lib.optionals cfg.debug [
    "-d"
    "1"
    "-FPSdata"
  ]
  ++ lib.optionals (!cfg.videoSync) [
    "-vsync"
    "no"
  ]
  ++ [
    "-p"
    "-s"
    cfg.resolution
    "-vs"
    cfg.videoSink
    "-as"
    cfg.audioSink
  ];
  uxplayKiosk = pkgs.writeShellScript "uxplay-kiosk" ''
    log_dir="''${XDG_STATE_HOME:-$HOME/.local/state}"
    mkdir -p "$log_dir"
    exec >> "$log_dir/uxplay-kiosk.log" 2>&1

    echo "=== uxplay kiosk start $(date --iso-8601=seconds) ==="
    export LIBSEAT_BACKEND=logind
    ${lib.optionalString cfg.debug ''
      export GST_DEBUG="playbin:3,hls*:3,soup*:3,${cfg.videoSink}:4"
    ''}
    export GST_PLUGIN_FEATURE_RANK="kmssink:0,ximagesink:0"

    exec ${lib.getExe pkgs.cage} -s -- ${lib.getExe pkgs.uxplay} ${lib.escapeShellArgs uxplayArgs}
  '';
  uxplayGreetdConfig = pkgs.writeText "uxplay-greetd.toml" ''
    [terminal]
    vt = 1

    [initial_session]
    command = "${uxplayKiosk}"
    user = "${cfg.user}"

    [default_session]
    command = "${uxplayKiosk}"
    user = "${cfg.user}"
  '';
in
{
  options.tleilax.airplayReceiver = {
    enable = lib.mkEnableOption "AirPlay mirroring receiver for the HDMI display";

    user = lib.mkOption {
      type = lib.types.str;
      default = "kabilan";
      description = "User that owns the AirPlay receiver process.";
    };

    name = lib.mkOption {
      type = lib.types.str;
      default = "tleilax";
      description = "AirPlay receiver name shown in iPadOS Screen Mirroring.";
    };

    resolution = lib.mkOption {
      type = lib.types.str;
      default = "1280x720@30";
      description = "Requested AirPlay mirroring resolution and refresh rate.";
    };

    softwareDecode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Force software H.264 decoding instead of GStreamer auto-selected hardware decoding.";
    };

    hardwareDecode = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use Raspberry Pi Video4Linux2 H.264 hardware decoding.";
    };

    bt709 = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable UxPlay's Raspberry Pi BT.709 color workaround for V4L2 decoding.";
    };

    hls = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable UxPlay HTTP Live Streaming support for YouTube app AirPlay video.";
      };

      version = lib.mkOption {
        type = lib.types.enum [
          2
          3
        ];
        default = 3;
        description = "UxPlay HLS video player version.";
      };
    };

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Start the AirPlay receiver at boot.";
    };

    restart = lib.mkOption {
      type = lib.types.enum [
        "always"
        "on-failure"
      ];
      default = "always";
      description = "Systemd restart policy for the AirPlay receiver.";
    };

    videoSink = lib.mkOption {
      type = lib.types.str;
      default = "glimagesink";
      description = "GStreamer video sink used for the HDMI output.";
    };

    audioSink = lib.mkOption {
      type = lib.types.str;
      default = "alsasink";
      description = "GStreamer audio sink used for HDMI/audio output.";
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable concise UxPlay and GStreamer diagnostics in the kiosk log.";
    };

    videoSync = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Synchronize mirrored video to audio timestamps.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open the legacy AirPlay mirroring ports on the LAN firewall.";
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.graphics.enable = true;
    services.avahi.openFirewall = true;

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [
        7000
        7001
        7100
      ];
      allowedUDPPorts = [
        6000
        6001
        7011
      ];
    };

    systemd.services.uxplay = {
      description = "UxPlay AirPlay mirroring receiver";
      after = [
        "network-online.target"
        "avahi-daemon.service"
        "sound.target"
      ];
      wants = [
        "network-online.target"
        "avahi-daemon.service"
      ];
      wantedBy = lib.mkIf cfg.autoStart [ "multi-user.target" ];
      conflicts = [ "greetd.service" ];

      serviceConfig = {
        ExecStart = "${lib.getExe pkgs.greetd} --config ${uxplayGreetdConfig}";
        Restart = cfg.restart;
        RestartSec = 5;
      };
    };

    users.users.${cfg.user}.extraGroups = [
      "audio"
      "netdev"
      "render"
      "video"
    ];

    users.groups.netdev = { };

    environment.systemPackages = [
      pkgs.cage
      pkgs.uxplay
    ];
  };
}
