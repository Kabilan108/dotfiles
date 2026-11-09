{ config, ... }:
let
  share = "//10.0.0.240/library";

  # The NAS share ACL decides who may write; these options only set how files
  # look on sietch. Same transport options as modules/nixos/backup.
  common = [
    "vers=3.1.1"
    "seal"
    "uid=kabilan"
    "gid=users"
    "nodev"
    "nosuid"
    "noexec"
    "_netdev"
    # With seal, each request is encrypted in a buffer sized from rsize/wsize.
    # At the 4 MiB default that is an order-4 allocation, which failed under
    # memory fragmentation mid-copy (ENOMEM on close). 1 MiB keeps it small.
    "rsize=1048576"
    "wsize=1048576"
  ];

  # Mounted on first use, so a missing NAS or placeholder credentials fail the
  # access instead of the boot.
  onDemand = [
    "x-systemd.automount"
    "x-systemd.idle-timeout=600"
    "x-systemd.mount-timeout=30s"
    "nofail"
  ];
in
{
  age.secrets = {
    library-ro-smb.file = ../../../secrets/library/sietch-ro-smb.age;
    library-rw-smb.file = ../../../secrets/library/sietch-rw-smb.age;
  };

  # svc-library-rw: Read/Write on the share. Used to copy the library over and
  # to add media.
  fileSystems."/library-rw" = {
    device = share;
    fsType = "cifs";
    options =
      common
      ++ onDemand
      ++ [
        "credentials=${config.age.secrets.library-rw-smb.path}"
        "file_mode=0664"
        "dir_mode=0775"
      ];
  };

  # svc-library-ro: Read Only on the share. Jellyfin reads it through the
  # /media bind. Mounted at boot and `hard`, so while the NAS is away reads
  # wait instead of failing and a library scan can't see files vanish.
  fileSystems."/library" = {
    device = share;
    fsType = "cifs";
    options = common ++ [
      "credentials=${config.age.secrets.library-ro-smb.path}"
      "ro"
      "hard"
      "file_mode=0444"
      "dir_mode=0555"
      "x-systemd.mount-timeout=60s"
    ];
  };
}
