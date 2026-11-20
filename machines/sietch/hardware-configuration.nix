{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [
    "dm-snapshot"
    "cryptd"
  ];
  boot.initrd.luks.devices."cryptroot".device = "/dev/disk/by-label/NIXOS_LUKS";
  boot.initrd.luks.devices."cryptroot".allowDiscards = true;
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  fileSystems."/vault" = {
    device = "/dev/disk/by-label/VAULT";
    fsType = "ext4";
  };

  swapDevices = [
    { device = "/dev/disk/by-label/SWAP"; }
  ];

  systemd.tmpfiles.rules = [
    "d /vault 1755 root root - -"
    "a /vault - - - - u::rwx,u:kabilan:rwx,g::r-x,m::rwx,o::r-x"
    "d /vault/userdata 1755 root root - -"
    "a /vault/userdata - - - - u::rwx,u:kabilan:rwx,g::r-x,m::rwx,o::r-x"
  ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.enableAllFirmware = true;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
