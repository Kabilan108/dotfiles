{
  config,
  displayServer,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.dictator;
  parakeetReduxCfg = config.dotfiles.services.parakeet-redux;
  systemName = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [ inputs.dictator.homeManagerModules.dictator ];

  options.dotfiles.services.dictator = {
    enable = lib.mkEnableOption "Dictator voice typing daemon and desktop app";

    activeProvider = lib.mkOption {
      type = lib.types.enum [
        "openai"
        "parakeet-redux"
        "siren"
      ];
      default = "siren";
      description = "Transcription provider selected in Dictator's generated configuration.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.activeProvider != "parakeet-redux" || parakeetReduxCfg.enable;
        message = "Selecting the parakeet-redux Dictator provider requires dotfiles.services.parakeet-redux.enable = true.";
      }
    ];

    services.dictator = {
      enable = true;
      package = inputs.dictator.packages.${systemName}.default;
      gui.enable = true;
      displayServer = displayServer;
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
            "parakeet-redux" = {
              endpoint = "http://127.0.0.1:${toString parakeetReduxCfg.port}/v1/audio/transcriptions";
              key = "local";
              model = "moondream/parakeet-redux";
            };
            siren = {
              endpoint = "https://siren.sole-pierce.ts.net/v1/audio/transcriptions";
              key = "\${env:SIREN_API_KEY}";
              model = "nvidia/parakeet-tdt-0.6b-v2";
            };
          };
        };
        enable_osd = true;
        notifications = "errors_only";
        audio.max_duration_min = 30;
        typing = {
          shortcut = "ctrl_shift_v";
          niri_app_shortcuts."com.t3tools.T3Code" = "ctrl_v";
        };
      };
    };

    systemd.user.services.dictator.Unit.X-Restart-Triggers = [
      config.home.file."${config.xdg.configHome}/dictator/config.json".source
    ];
  };
}
