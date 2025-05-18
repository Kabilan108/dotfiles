# this script provides an example for partitioning a drive for a nixos install
# using a LVM group with FDE (LUKS)
#
# info: replace any /dev/sdx* with the correct device

DRIVE=/dev/sdx

# partition the drive
sudo gdisk $DRIVE
# run the folliwing:
#   help          - ?
#   new GPT       - o
#   efi partition - n <default> <default> +1G ef00
#   lvm partition - n <default> <default> <default> 8e00
#   save & exit   - w
#
# the two partitions will show up as /dev/sdx1 and /dev/sdx2

# create the luks container
sudo cryptsetup -v -y \
    -c aes-xts-plain64 -s 512 -h sha512 -i 2000 --use-random \
    --label=NIXOS_LUKS luksFormat --type luks2 $DRIVE

# open luks container
sudo cryptsetup open --type luks $DRIVE cryptroot

# check that the mapped device exists:
ls /dev/mapper/cryptroot

# create a physical volume with a volume group
sudo pvcreate         /dev/mapper/cryptroot
sudo vgcreate lvmroot /dev/mapper/cryptroot

# create partitions
sudo lvcreate -L32G       lvmroot -n swap
sudo lvcreate -L256G      lvmroot -n root
sudo lvcreate -l 100%FREE lvmroot -n vault

# format filesystems
sudo mkfs.fat  -n BOOT -F32 /dev/sdx1
sudo mkfs.ext4 -L ROOT      /dev/mapper/lvmroot-root
sudo mkfs.ext4 -L VAULT     /dev/mapper/lvmroot-vault
sudo mkswap    -L SWAP      /dev/mapper/lvmroot-swap

# mount the partitions
sudo mount /dev/disk/by-label/ROOT /mnt
sudo mkdir /mnt/boot
sudo mkdir /mnt/vault
sudo mount -o umask=0077 /dev/disk/by-label/BOOT /mnt/boot
sudo mount /dev/disk/by-label/VAULT /mnt/vault
sudo swapon -L SWAP

# generate a minimal nixos config
sudo nixos-generate-config --root /mnt

# info: copy over the config files from the dotfiles repo
#       preserve the generated hardware-configuration.nix file

# install nixos
sudo nixos-install --root /mnt --no-root-passwd
sudo nixos-enter --root /mnt -c 'passwd kabilan'

# unmounting
sudo umount -R /mnt
sudo swapoff -L SWAP
sudo vgchange -a n lvmroot
sudo cryptsetup close /dev/mapper/cryptroot

reboot
