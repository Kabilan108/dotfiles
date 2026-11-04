# The 1 TB Samsung T5 USB SSD. Partition 1 is the FAT boot partition the Pi
# firmware reads: firmware, u-boot, extlinux, kernels, initrds and the boot
# environment's SSH host key. Partition 2 is LUKS2 with Adiantum, which is
# fast on the Pi 4's CPU (no AES instructions), holding ext4 for /.
#
# `device` is only used when formatting (docs/tleilax-install.md); the
# installed system finds both partitions by their GPT labels.
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
