# tleilax boots from a LUKS2 Adiantum USB SSD and unlocks over SSH in the initrd

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The Pi 4 firmware loads u-boot from a FAT boot partition, u-boot reads `/boot/extlinux/extlinux.conf`, and the initrd must unlock the LUKS root. The Pi 4 CPU has no AES instructions. u-boot's extlinux loader can't append secrets to the initrd, and `boot.initrd.network.ssh.hostKeys` would put the private key in the world-readable Nix store. Kernel 6.18 has no poly1305 module.

## Decision

- The disk is a 1 TB Samsung T5 USB SSD. Partition 1 is FAT and holds the firmware, u-boot, extlinux, kernels, initrds and the boot environment's SSH host key. Partition 2 is LUKS2 with Adiantum (`xchacha12,aes-adiantum-plain64`), which is fast without AES instructions, holding ext4 for `/`. disko's `device` is used only when formatting; the installed system finds partitions by GPT label.
- The initrd loads adiantum, nhpoly1305, nhpoly1305_neon and chacha20; adiantum and nhpoly1305 pull in libpoly1305 themselves. It also loads `pcie_brcmstb`, `reset_raspberrypi`, `xhci_pci`, `usb_storage` and `uas`, because the SSD sits behind the PCIe USB 3 controller, and `genet` plus `broadcom` for Ethernet and its PHY. Wi-Fi and Bluetooth modules are blacklisted.
- `config.txt` sets `enable_uart=1` because u-boot needs the UART whether or not anything uses it, and `avoid_warnings=1` so the firmware does not draw over the kernel's framebuffer. u-boot passes the mainline `bcm2711-rpi-*.dtb` device trees. The HDMI console comes last on the kernel command line so the passphrase prompt shows on screen.
- The firmware, u-boot and `config.txt` are copied to the boot partition once at install; rebuilds update only extlinux and the kernels.
- The systemd initrd brings up Ethernet with DHCP and runs sshd on `initrdUnlock.port` (2222). Logging in as root answers the passphrase prompt and does nothing else. Only YubiKey logins of hosts allowed into tleilax (jacurutu) are authorized, and the HDMI console asks at the same time.
- The boot environment's host key sits on the unencrypted boot partition, where an appended key would end up anyway, and the `initrd-ssh-host-key` unit copies it in before sshd starts. It is not the system host key, which stays on the encrypted root.
- On jacurutu, `tleilax-unlock` and `tleilax-unlock-away` use the hardware keys only. The boot key is pinned as `<host>-initrd` in `/etc/ssh/ssh_known_hosts` and any other key is refused. The away alias jumps through `initrdUnlock.jumpHost` (sietch), which only forwards the encrypted connection.

## Consequences

Changing firmware, u-boot or `config.txt` needs a manual copy to the boot partition. Anyone with physical access to the SSD can read the boot host key, which is no worse than an appended key. `lanAddress` and the boot `hostPubkey` are filled in during the install and must be updated if either changes.

## Where

- `machines/tleilax/disko.nix`
- `machines/tleilax/hardware.nix` (`configTxt`, `boot.initrd.availableKernelModules`, `boot.initrd.luks.cryptoModules`, `boot.kernelParams`, `system.build.raspberryPiFirmware`)
- `machines/tleilax/initrd-unlock.nix` (`initrd-ssh-host-key`)
- `lib/fleet.nix` (`hosts.tleilax.initrdUnlock`)
- `modules/home/fleet.nix` (`unlockSshSettings`)
