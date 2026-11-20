# shellcheck shell=bash

DRIVE=/dev/sdx

sudo gdisk $DRIVE

sudo cryptsetup -v -y \
    -c aes-xts-plain64 -s 512 -h sha512 -i 2000 --use-random \
    --label=NIXOS_LUKS luksFormat --type luks2 $DRIVE

sudo cryptsetup open --type luks $DRIVE cryptroot

ls /dev/mapper/cryptroot

sudo pvcreate         /dev/mapper/cryptroot
sudo vgcreate lvmroot /dev/mapper/cryptroot

sudo lvcreate -L32G       lvmroot -n swap
sudo lvcreate -L256G      lvmroot -n root
sudo lvcreate -l 100%FREE lvmroot -n vault

sudo mkfs.fat  -n BOOT -F32 /dev/sdx1
sudo mkfs.ext4 -L ROOT      /dev/mapper/lvmroot-root
sudo mkfs.ext4 -L VAULT     /dev/mapper/lvmroot-vault
sudo mkswap    -L SWAP      /dev/mapper/lvmroot-swap

sudo mount /dev/disk/by-label/ROOT /mnt
sudo mkdir /mnt/boot
sudo mkdir /mnt/vault
sudo mount -o umask=0077 /dev/disk/by-label/BOOT /mnt/boot
sudo mount /dev/disk/by-label/VAULT /mnt/vault
sudo swapon -L SWAP

sudo nixos-generate-config --root /mnt


sudo nixos-install --root /mnt --no-root-passwd
sudo nixos-enter --root /mnt -c 'passwd kabilan'

sudo umount -R /mnt
sudo swapoff -L SWAP
sudo vgchange -a n lvmroot
sudo cryptsetup close /dev/mapper/cryptroot

reboot
