{ ... }:
{
  selfhost.tailnetServices.jellyfin.port = 8096;

  # Library paths inside the old container were /media/...; keeping them valid
  # preserves watch state and metadata without touching the database.
  # _netdev moves the bind under remote-fs.target. As a local mount it joined
  # local-fs.target, which then waited on /library and the network, and
  # systemd broke the cycle at boot by mounting /library before the network.
  fileSystems."/media" = {
    device = "/library";
    fsType = "none";
    options = [
      "bind"
      "_netdev"
    ];
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
