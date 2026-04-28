{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.install-uv-tools;
in
{
  options.dotfiles.services.install-uv-tools.enable = lib.mkEnableOption "uv tool refresh";

  config = lib.mkIf cfg.enable {
    systemd.user.services.install-uv-tools = {
      Unit = {
        Description = "Install/Update uv tools";
        After = "network-online.target";
      };
      Service = {
        Type = "oneshot";
        ExecStart = [
          "${pkgs.uv}/bin/uv tool install -U --with llm-cmd --with llm-openrouter --with llm-tmux-fragments llm"
          "${pkgs.uv}/bin/uv tool install -U --from git+https://github.com/kabilan108/viewh5 viewh5"
        ];
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
