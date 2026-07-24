{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.codex-remote-control;

  remoteControl = command: pkgs.writeShellScript "codex-remote-control-${command}" ''
    set -eu
    source "$HOME/.bashenv"

    exec codex remote-control ${command}
  '';
in
{
  options.dotfiles.services.codex-remote-control = {
    enable = lib.mkEnableOption "Codex remote-control app-server daemon";
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.codex-remote-control = {
      Unit = {
        Description = "Codex remote-control app-server daemon";
        After = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = remoteControl "start";
        ExecStop = remoteControl "stop";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
