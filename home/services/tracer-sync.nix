{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.tracer-sync;
  thisHost = osConfig.networking.hostName;
in
{
  options.dotfiles.services.tracer-sync = {
    enable = lib.mkEnableOption "one-way tracer archive push to the authoritative host";
    target = lib.mkOption {
      type = lib.types.str;
      default = "sietch";
      description = "Push remote name in tracer config.";
    };
    sshHost = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.target}-agent";
      description = "ssh host alias to reach the target non-interactively (BatchMode + agent key), resolved via ~/.ssh/config.";
    };
    targetDir = lib.mkOption {
      type = lib.types.str;
      default = "/vault/userdata/tracer-ingest/${thisHost}";
    };
  };

  config = lib.mkIf cfg.enable {
    # tracer push replaces the old raw rsync: it transfers only new/changed
    # transcripts and the receiver merge-preserves annotations (tags/outcome)
    # instead of clobbering them, which is what allows receiver-side pipeline
    # tags like wiki:compiled to survive re-pushes.
    programs.tracer.settings.push.remotes = [
      {
        name = cfg.target;
        host = cfg.sshHost;
        dest = cfg.targetDir;
      }
    ];

    systemd.user.services.tracer-sync = {
      Unit.Description = "Push tracer archive to ${cfg.target}";
      Service = {
        Type = "oneshot";
        # tracer shells out to plain `ssh <host>`; identity/BatchMode come from
        # the sshHost alias in ~/.ssh/config, not from flags here.
        Environment = [ "PATH=${lib.makeBinPath [ pkgs.openssh ]}" ];
        ExecStart = "${config.programs.tracer.package}/bin/tracer push ${cfg.target}";
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
