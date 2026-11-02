# Raspberry Pi 4 booting from the USB SSD: the Pi firmware loads u-boot from
# the FAT boot partition, u-boot reads /boot/extlinux/extlinux.conf, and the
# initrd unlocks the LUKS root (initrd-unlock.nix).
{
  options,
  pkgs,
  ...
}:
let
  configTxt = pkgs.writeText "config.txt" ''
    kernel=u-boot.bin
    arm_64bit=1
    # u-boot needs the UART enabled whether or not anything uses it.
    enable_uart=1
    # Keep the firmware from drawing over the kernel's framebuffer.
    avoid_warnings=1
    enable_gic=1
    armstub=armstub8-gic.bin
    disable_overscan=1
    arm_boost=1
  '';
in
{
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible = {
    enable = true;
    configurationLimit = 10;
  };

  # u-boot passes these mainline device trees to the kernel.
  hardware.deviceTree.filter = "bcm2711-rpi-*.dtb";

  # HDMI comes last, so the passphrase prompt shows on the screen.
  boot.kernelParams = [
    "console=ttyS0,115200n8"
    "console=ttyAMA0,115200n8"
    "console=tty0"
  ];

  boot.initrd.availableKernelModules = [
    # The SSD sits behind the PCIe USB 3 controller.
    "pcie_brcmstb"
    "reset_raspberrypi"
    "xhci_pci"
    "usb_storage"
    "uas"
    # Ethernet and its PHY, for the boot-time SSH unlock.
    "genet"
    "broadcom"
  ];

  # Adiantum (disko.nix). Kernel 6.18 has no poly1305 module; adiantum and
  # nhpoly1305 pull in libpoly1305 themselves.
  boot.initrd.luks.cryptoModules = options.boot.initrd.luks.cryptoModules.default ++ [
    "adiantum"
    "nhpoly1305"
    "nhpoly1305_neon"
    "chacha20"
  ];

  # Ethernet only.
  boot.blacklistedKernelModules = [
    "brcmfmac"
    "hci_uart"
    "btbcm"
  ];

  # The Pi firmware, u-boot and config.txt for the boot partition. Copied
  # there once at install; rebuilds only update extlinux and the kernels.
  system.build.raspberryPiFirmware = pkgs.runCommand "tleilax-firmware" { } ''
    mkdir "$out"
    cp ${pkgs.raspberrypifw}/share/raspberrypi/boot/{start4*.elf,fixup4*.dat,bcm2711-rpi-4-b.dtb} "$out"/
    cp ${pkgs.raspberrypi-armstubs}/armstub8-gic.bin "$out"/
    cp ${pkgs.ubootRaspberryPiAarch64}/u-boot.bin "$out"/
    cp ${configTxt} "$out"/config.txt
  '';
}
