{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.kittylitter;
  homeDir = config.home.homeDirectory;
  pnpmHome = "${homeDir}/.local/share/pnpm";
in
{
  options.dotfiles.services.kittylitter.enable = lib.mkEnableOption "kittylitter bridge daemon";

  config = lib.mkIf cfg.enable {
    systemd.user.services.kittylitter = {
      Unit = {
        Description = "Alleycat bridge daemon";
        After = [ "network-online.target" ];
      };
      Service = {
        Type = "simple";
        Environment = [
          "PATH=${
            lib.makeBinPath [
              pkgs.coreutils
              pkgs.gnused
              pkgs.nodejs_24
            ]
          }:${pnpmHome}:${homeDir}/.bun/bin:${homeDir}/.local/bin:${homeDir}/bin:/run/current-system/sw/bin"
        ];
        ExecStart = "${pnpmHome}/kittylitter serve";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
