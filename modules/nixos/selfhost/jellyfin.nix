{ ... }:
{
  selfhost.tailnetServices.jellyfin.port = 8096;

  # Library paths inside the old container were /media/...; keeping them valid
  # preserves watch state and metadata without touching the database.
  fileSystems."/media" = {
    device = "/library";
    fsType = "none";
    options = [ "bind" ];
    depends = [ "/library" ];
  };

  services.jellyfin.enable = true;

  # video/render: NVENC device access
  users.users.jellyfin.extraGroups = [
    "video"
    "render"
  ];

  systemd.services.jellyfin = {
    # An unmounted NAS must stop Jellyfin, not show it an empty library.
    unitConfig.RequiresMountsFor = "/media";
    environment.JELLYFIN_PublishedServerUrl = "https://jellyfin.sole-pierce.ts.net";
  };
}
