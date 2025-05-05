#!/usr/bin/env bash

echo "The Script Begins..."
set -e  # Exit on error
set -x  # Print commands as they run (useful for debugging)

echo "Creating LVM ..."
sudo pvcreate nvme0n1p7
sudo vgcreate ArchMain nvme0n1p7
sudo lvcreate -L 8G ArchMain -n Swap
sudo lvcreate -L 64G ArchMain -n cryptRoot
sudo lvcreate -l 100%FREE ArchMain -n cryptHome

echo "Encrypting lv ..."
sudo cryptsetup -v -y -c aes-xts-plain64 -s 512 -h sha512 -i 2000 --use-random --label=ARCH_ROOT luksFormat --type luks2 /dev/ArchMain/cryptRoot
sudo cryptsetup -v -y -c aes-xts-plain64 -s 512 -h sha512 -i 2000 --use-random --label=ARCH_HOME luksFormat --type luks2 /dev/ArchMain/cryptHome
sudo cryptsetup open --type luks /dev/ArchMain/cryptRoot ArchRoot
sudo cryptsetup open --type luks /dev/ArchMain/cryptHome ArchHome

echo "Making FileSystem ..."
sudo mkfs.fat  -n ARCH_BOOT -F32 nvme0n1p5
sudo mkfs.fat  -n ARCH_EFI -F32 nvme0n1p6
sudo mkswap -L ARCH_SWAP /dev/ArchMain/Swap
sudo mkfs.btrfs -L ARCH_ROOT /dev/mapper/ArchRoot
sudo mkfs.btrfs -L ARCH_HOME /dev/mapper/ArchHome

echo "Making btrfs Subvolume ..."

sudo mount -t btrfs /dev/mapper/ArchRoot /mnt
cd /mnt
sudo btrfs subvolume create @root
sudo btrfs subvolume create @pkg
sudo btrfs subvolume create @cache
sudo btrfs subvolume create @.snap
cd 
umount /mnt
sudo mount -t btrfs -o rw,ssd,noatime,compress=zstd,discard=async,subvol=@root /dev/mapper/ArchRoot /mnt
sudo mount -t btrfs -o rw,ssd,noatime,compress=zstd,discard=async,subvol=@cache --mkdir /dev/mapper/ArchRoot /mnt/var/cache
sudo mount -t btrfs -o rw,ssd,noatime,compress=zstd,discard=async,subvol=@pkg --mkdir /dev/mapper/ArchRoot /mnt/var/lib/pacman
sudo mount -t btrfs -o rw,ssd,noatime,compress=zstd,discard=async,subvol=@.snap --mkdir /dev/mapper/ArchRoot /mnt/.snap

sudo mount -t btrfs --mkdir /dev/mapper/ArchHome /mnt/home
cd /mnt/home
sudo btrfs subvolume create @home
cd
sudo umount -R /mnt/home
sudo mount -t btrfs -o rw,ssd,noatime,compress=zstd,discard=async,subvol=@home --mkdir /dev/mapper/ArchHome /mnt/home

sudo mount -o umask=0077 --mkdir /dev/nvme0n1p5 /mnt/boot
sudo mount -o umask=0077 --mkdir /dev/nvme0n1p6 /mnt/boot/efi
sudo swapon /dev/ArchMain/Swap
sudo swapon -a

lsblk

