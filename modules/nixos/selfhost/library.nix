{ config, ... }:
let
  share = "//10.0.0.240/library";

  common = [
    "vers=3.1.1"
    "seal"
    "uid=kabilan"
    "gid=users"
    "nodev"
    "nosuid"
    "noexec"
    "_netdev"
    "rsize=1048576"
    "wsize=1048576"
  ];

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
