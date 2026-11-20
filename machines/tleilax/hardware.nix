{
  options,
  pkgs,
  ...
}:
let
  configTxt = pkgs.writeText "config.txt" ''
    kernel=u-boot.bin
    arm_64bit=1
    enable_uart=1
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

  hardware.deviceTree.filter = "bcm2711-rpi-*.dtb";

  boot.kernelParams = [
    "console=ttyS0,115200n8"
    "console=ttyAMA0,115200n8"
    "console=tty0"
  ];

  boot.initrd.availableKernelModules = [
    "pcie_brcmstb"
    "reset_raspberrypi"
    "xhci_pci"
    "usb_storage"
    "uas"
    "genet"
    "broadcom"
  ];

  boot.initrd.luks.cryptoModules = options.boot.initrd.luks.cryptoModules.default ++ [
    "adiantum"
    "nhpoly1305"
    "nhpoly1305_neon"
    "chacha20"
  ];

  boot.blacklistedKernelModules = [
    "brcmfmac"
    "hci_uart"
    "btbcm"
  ];

  system.build.raspberryPiFirmware = pkgs.runCommand "tleilax-firmware" { } ''
    mkdir "$out"
    cp ${pkgs.raspberrypifw}/share/raspberrypi/boot/{start4*.elf,fixup4*.dat,bcm2711-rpi-4-b.dtb} "$out"/
    cp ${pkgs.raspberrypi-armstubs}/armstub8-gic.bin "$out"/
    cp ${pkgs.ubootRaspberryPiAarch64}/u-boot.bin "$out"/
    cp ${configTxt} "$out"/config.txt
  '';
}
