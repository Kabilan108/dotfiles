{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.services.tracer-digest;
  homeDir = config.home.homeDirectory;
in
{
  options.dotfiles.services.tracer-digest = {
    enable = lib.mkEnableOption "weekly learning digest over new tracer sessions";
    digestDir = lib.mkOption {
      type = lib.types.str;
      default = "/vault/notes/coppermind/coppermind/01-logs/agent-digests";
      description = "Where digests land; re-point at the agent wiki once its structure settles.";
    };
    onCalendar = lib.mkOption {
      type = lib.types.str;
      default = "Sun 18:00";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.tracer-digest = {
      Unit.Description = "Weekly tracer learning digest";
      Service = {
        Type = "oneshot";
        Environment = [ "TRACER_DIGEST_DIR=${cfg.digestDir}" ];
        ExecStart = "/usr/bin/env bash -lc '${homeDir}/dotfiles/bin/tracer-digest'";
      };
    };

    systemd.user.timers.tracer-digest = {
      Unit.Description = "Weekly tracer learning digest";
      Timer = {
        OnCalendar = cfg.onCalendar;
        RandomizedDelaySec = "30m";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
