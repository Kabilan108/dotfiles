{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.dictator;
  systemName = pkgs.stdenv.hostPlatform.system;
  # dictator probes for a notification server once at startup and stays silent
  # for its whole run if none is registered yet, which happens when a switch
  # restarts it alongside the shell. Give the shell a moment, then start anyway.
  waitForNotifications = pkgs.writeShellScript "dictator-wait-for-notifications" ''
    for _ in $(${pkgs.coreutils}/bin/seq 50); do
      ${pkgs.systemd}/bin/busctl --user status org.freedesktop.Notifications >/dev/null 2>&1 && exit 0
      ${pkgs.coreutils}/bin/sleep 0.2
    done
    echo "no notification server after 10s; starting without desktop notifications"
  '';
in
{
  imports = [ inputs.dictator.homeManagerModules.dictator ];

  options.dotfiles.services.dictator = {
    enable = lib.mkEnableOption "Dictator voice typing daemon and desktop app";

    activeProvider = lib.mkOption {
      type = lib.types.enum [
        "openai"
        "siren"
      ];
      default = "siren";
      description = "Transcription provider selected in Dictator's generated configuration.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.dictator = {
      enable = true;
      package = inputs.dictator.packages.${systemName}.default;
      gui.enable = true;
      displayServer = "wayland";
      logLevel = "INFO";
      environmentFile = "/run/agenix/secrets/dictator-env";
      settings = {
        api = {
          active_provider = cfg.activeProvider;
          timeout = 60;
          providers = {
            openai = {
              endpoint = "https://api.openai.com/v1/audio/transcriptions";
              key = "\${env:OPENAI_API_KEY}";
              model = "gpt-4o-transcribe";
            };
            siren = {
              endpoint = "https://siren.sole-pierce.ts.net/v1/audio/transcriptions";
              key = "\${env:SIREN_API_KEY}";
              model = "nvidia/parakeet-tdt-0.6b-v2";
              send_vocabulary = true;
            };
          };
        };
        enable_osd = true;
        notifications = "errors_only";
        audio.max_duration_min = 15;
        typing = {
          shortcut = "ctrl_shift_v";
          niri_app_shortcuts."com.t3tools.T3Code" = "ctrl_v";
        };
      };
    };

    systemd.user.services.dictator.Unit.X-Restart-Triggers = [
      config.home.file."${config.xdg.configHome}/dictator/config.json".source
    ];

    # The dictator module sets ExecStartPre as a single string; a drop-in adds a
    # second one after it.
    xdg.configFile."systemd/user/dictator.service.d/wait-for-notifications.conf".text = ''
      [Service]
      ExecStartPre=${waitForNotifications}
    '';
  };
}
