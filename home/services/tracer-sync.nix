{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.tracer-sync;
  homeDir = config.home.homeDirectory;
  thisHost = osConfig.networking.hostName;
in
{
  options.dotfiles.services.tracer-sync = {
    enable = lib.mkEnableOption "one-way tracer archive push to the authoritative host";
    target = lib.mkOption {
      type = lib.types.str;
      default = "sietch";
    };
    targetDir = lib.mkOption {
      type = lib.types.str;
      default = "/vault/userdata/tracer-ingest/${thisHost}";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.tracer-sync = {
      Unit.Description = "Push tracer archive to ${cfg.target}";
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.rsync}/bin/rsync -a --mkpath -e '${pkgs.openssh}/bin/ssh -i ${homeDir}/.ssh/agent-${thisHost} -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=5' ${homeDir}/.local/share/tracer/archive/ ${cfg.target}:${cfg.targetDir}/";
      };
    };

    systemd.user.timers.tracer-sync = {
      Unit.Description = "Daily tracer archive push";
      Timer = {
        OnCalendar = "daily";
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
