---
paths:
  - machines/tleilax/disko.nix
  - machines/tleilax/hardware.nix
  - machines/tleilax/initrd-unlock.nix
---

# tleilax encrypts its root with Adiantum and unlocks over SSH with a boot-only host key

tleilax boots from a USB SSD: a FAT partition holds the firmware, u-boot, extlinux, kernels and initrds, and the root is LUKS2 with Adiantum (`xchacha12,aes-adiantum-plain64`) because the Pi 4 CPU has no AES instructions and AES-XTS would be slow. The initrd runs sshd so Tony can type the passphrase with a YubiKey login. Its host key is a separate key stored on the unencrypted boot partition and copied in by the `initrd-ssh-host-key` unit: u-boot's extlinux loader cannot append secrets to the initrd, and `boot.initrd.network.ssh.hostKeys` would put the private key in the world-readable Nix store.

## Consequences

- Changing the cipher means reformatting the disk and reinstalling.
- Anyone with physical access to the SSD can read the boot host key, which is no worse than an appended key. The system host key, which decrypts the agenix secrets, stays on the encrypted root.
