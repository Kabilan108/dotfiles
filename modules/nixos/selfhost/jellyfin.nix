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

  services.jellyfin.enable = true;

  # users: yt-dlp plugin writes to /library/downloads (group-writable);
  # video/render: NVENC device access
  users.users.jellyfin.extraGroups = [
    "users"
    "video"
    "render"
  ];

  systemd.services.jellyfin = {
    path = [
      pkgs.yt-dlp
      pkgs.python3
    ];
    environment.JELLYFIN_PublishedServerUrl = "https://jellyfin.sole-pierce.ts.net";
  };
}
