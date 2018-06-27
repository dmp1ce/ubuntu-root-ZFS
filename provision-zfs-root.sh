#!/bin/sh

# Create bootable Ubuntu pool

# Following guides from these URLs:
# https://github.com/zfsonlinux/zfs/wiki/Ubuntu-18.04-Root-on-ZFS
# https://blog.heckel.xyz/2016/12/31/move-existing-linux-install-zfs-root/

# Exit if pool has already been created.
if [ "$(zpool list | grep -c 'no pools available')" -eq 0 ]; then
    exit
fi

# Format disk
# BIOS
sgdisk -a1 -n2:34:2047 -t2:EF02 /dev/disk/by-path/pci-0000:00:14.0-scsi-0:0:2:0
# UEFI
#sgdisk -n3:1M:+512M -t3:EF00 /dev/disk/by-path/pci-0000:00:14.0-scsi-0:0:2:0
sgdisk -n1:0:0 -t1:BF01 /dev/disk/by-path/pci-0000:00:14.0-scsi-0:0:2:0

# Try to let sgdisk do it's thing
sync
sleep 5

# Create root pool
zpool create -o ashift=12 \
      -O atime=off -O canmount=off -O compression=lz4 -O normalization=formD \
      -O xattr=sa -O mountpoint=/ -R /mnt \
      rpool /dev/disk/by-path/pci-0000:00:14.0-scsi-0:0:2:0-part1
zfs create -o canmount=off -o mountpoint=none rpool/ROOT
zfs create -o canmount=noauto -o mountpoint=/ rpool/ROOT/ubuntu
zfs mount rpool/ROOT/ubuntu

# Copy system to root pool
rsync -a --one-file-system / /mnt/

# Make system bootable
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys
mount --bind /run /mnt/run

cat << EOF | chroot /mnt
update-grub
grub-install /dev/sda
EOF

# Unmount
mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | xargs -i{} umount -lf {}
zpool export rpool

# All done. Try to reboot.
reboot
