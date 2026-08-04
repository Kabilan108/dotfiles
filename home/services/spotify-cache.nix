{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.spotify-cache;
in
{
  options.dotfiles.services.spotify-cache.enable = lib.mkEnableOption "Spotify cache cleanup";

  config = lib.mkIf cfg.enable {
    systemd.user.services.clean-spotify-cache = {
      Unit.Description = "Delete Spotify cache";
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.coreutils}/bin/rm -rf %h/.cache/spotify";
      };
    };

    systemd.user.timers.clean-spotify-cache = {
      Unit.Description = "Daily Spotify cache cleanup";
      Timer = {
        OnCalendar = "daily";
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
