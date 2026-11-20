{
  disko.devices.disk.ssd = {
    type = "disk";
    device = "/dev/sda";
    content = {
      type = "gpt";
      partitions = {
        boot = {
          priority = 1;
          size = "2G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            extraArgs = [
              "-F"
              "32"
              "-n"
              "TLEILAXBOOT"
            ];
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            extraFormatArgs = [
              "--type"
              "luks2"
              "--cipher"
              "xchacha12,aes-adiantum-plain64"
              "--key-size"
              "256"
              "--hash"
              "sha256"
              "--pbkdf"
              "argon2id"
              "--sector-size"
              "4096"
            ];
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
