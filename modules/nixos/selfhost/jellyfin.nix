{ ... }:
{
  selfhost.tailnetServices.jellyfin.port = 8096;

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

  users.users.jellyfin.extraGroups = [
    "video"
    "render"
  ];

  systemd.services.jellyfin = {
    unitConfig.RequiresMountsFor = "/media";
    environment.JELLYFIN_PublishedServerUrl = "https://jellyfin.sole-pierce.ts.net";
  };
}
