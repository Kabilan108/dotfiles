{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.install-tools;
  homeDir = config.home.homeDirectory;
  pnpmHome = "${homeDir}/.local/share/pnpm";

  installTools = pkgs.writeShellScript "install-tools" ''
    set -euo pipefail

    ${pkgs.uv}/bin/uv tool install -U --with llm-cmd --with llm-openrouter --with llm-tmux-fragments llm
    ${pkgs.uv}/bin/uv tool install -U --from git+https://github.com/kabilan108/viewh5 viewh5

    ${pkgs.pnpm}/bin/pnpm add -g @steipete/summarize ccusage
  '';
in
{
  options.dotfiles.services.install-tools.enable = lib.mkEnableOption "third-party tool refresh";

  config = lib.mkIf cfg.enable {
    systemd.user.services.install-tools = {
      Unit = {
        Description = "Install/Update third-party tools";
        After = "network-online.target";
      };
      Service = {
        Type = "oneshot";
        Environment = [
          "PNPM_HOME=${pnpmHome}"
          "PATH=${
            lib.makeBinPath [
              pkgs.git
              pkgs.nodejs_24
              pkgs.pnpm
              pkgs.uv
            ]
          }:${pnpmHome}:${homeDir}/.local/bin"
        ];
        ExecStart = "${installTools}";
      };
    };
  };
}
