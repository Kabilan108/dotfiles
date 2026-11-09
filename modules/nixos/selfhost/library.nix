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

  # svc-library-ro: Read Only on the share. Verifies the copy until the cutover
  # moves Jellyfin's /library here.
  fileSystems."/library-nas" = {
    device = share;
    fsType = "cifs";
    options =
      common
      ++ onDemand
      ++ [
        "credentials=${config.age.secrets.library-ro-smb.path}"
        "ro"
        "file_mode=0444"
        "dir_mode=0555"
      ];
  };
}
