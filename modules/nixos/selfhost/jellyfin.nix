{ pkgs, ... }:
{
  selfhost.tailnetServices.jellyfin.port = 8096;

  # Library paths inside the old container were /media/...; keeping them valid
  # preserves watch state and metadata without touching the database.
  fileSystems."/media" = {
    device = "/library";
    fsType = "none";
    options = [ "bind" ];
  };

  services.jellyfin = {
    enable = true;
    # The compose container ran as uid 1000; existing state and the yt-dlp
    # plugin's library writes assume this user.
    user = "kabilan";
    group = "users";
  };

  systemd.services.jellyfin = {
    path = [
      pkgs.yt-dlp
      pkgs.python3
    ];
    environment.JELLYFIN_PublishedServerUrl = "https://jellyfin.sole-pierce.ts.net";
  };
}
