# jacurutu disk partitioning

Manual runbook for partitioning a drive for a NixOS install on jacurutu using LVM inside LUKS2.

Replace the placeholders in every command with the target device paths:

- `<DISK>`: the whole target drive, such as `/dev/sdx` or `/dev/nvme0n1`
- `<EFI_PART>`: the first partition created below, such as `/dev/sdx1` or `/dev/nvme0n1p1`
- `<LUKS_PART>`: the second partition created below, such as `/dev/sdx2` or `/dev/nvme0n1p2`

## 1. Partition the drive

```sh
sudo gdisk <DISK>
```

Inside `gdisk`, create a new GPT with an EFI system partition and an LVM/LUKS partition:

- `?`: help
- `o`: new GPT
- `n`, default partition number, default first sector, `+1G`, type `ef00`: EFI partition, `<EFI_PART>`
- `n`, default partition number, default first sector, default last sector, type `8e00`: LUKS/LVM partition, `<LUKS_PART>`
- `w`: save and exit

## 2. Create and open the LUKS container

The old partitioning script mistakenly ran `cryptsetup luksFormat` and `cryptsetup open` on the whole disk instead of the LUKS partition. Point both commands at `<LUKS_PART>`.

```sh
sudo cryptsetup -v -y \
    -c aes-xts-plain64 -s 512 -h sha512 -i 2000 --use-random \
    --label=NIXOS_LUKS luksFormat --type luks2 <LUKS_PART>

sudo cryptsetup open --type luks <LUKS_PART> cryptroot
ls /dev/mapper/cryptroot
```

## 3. Create the LVM volumes

```sh
sudo pvcreate         /dev/mapper/cryptroot
sudo vgcreate lvmroot /dev/mapper/cryptroot

sudo lvcreate -L32G       lvmroot -n swap
sudo lvcreate -L256G      lvmroot -n root
sudo lvcreate -l 100%FREE lvmroot -n vault
```

## 4. Format filesystems and swap

```sh
sudo mkfs.fat  -n BOOT -F32 <EFI_PART>
sudo mkfs.ext4 -L ROOT      /dev/mapper/lvmroot-root
sudo mkfs.ext4 -L VAULT     /dev/mapper/lvmroot-vault
sudo mkswap    -L SWAP      /dev/mapper/lvmroot-swap
```

## 5. Mount filesystems and enable swap

```sh
sudo mount /dev/disk/by-label/ROOT /mnt
sudo mkdir /mnt/boot
sudo mkdir /mnt/vault
sudo mount -o umask=0077 /dev/disk/by-label/BOOT /mnt/boot
sudo mount /dev/disk/by-label/VAULT /mnt/vault
sudo swapon -L SWAP
```

## 6. Generate and adjust NixOS configuration

```sh
sudo nixos-generate-config --root /mnt
```

Copy the configuration files from the dotfiles repository and preserve the generated `hardware-configuration.nix`, then edit `hardware-configuration.nix`:

- Set the initrd kernel modules and LUKS root device:

```nix
boot.initrd.kernelModules = [ "dm-snapshot" "cryptd" ];
boot.initrd.luks.devices."cryptroot".device = "/dev/disk/by-label/NIXOS_LUKS";
```

- Change the `device` attribute of each `fileSystems.*` entry from `/dev/disk/by-uuid` to `/dev/disk/by-label`.

## 7. Install NixOS and set the user password

```sh
sudo nixos-install --root /mnt --no-root-passwd
sudo nixos-enter --root /mnt -c 'passwd kabilan'
```

## 8. Unmount, close volumes, and reboot

```sh
sudo umount -R /mnt
sudo swapoff -L SWAP
sudo vgchange -a n lvmroot
sudo cryptsetup close /dev/mapper/cryptroot

reboot
```
