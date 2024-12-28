#!/usr/bin/env bash

# Variables
DISK="/dev/sda"      # Replace with your target disk

#script

echo "The Script Begins..."
set -e  # Exit on error
set -x  # Print commands as they run (useful for debugging)

echo "Creating LVM ..."
sudo pvcreate "${DISK}"2
sudo vgcreate NixMain "${DISK}"2
sudo lvcreate -L8G NixMain -n swap
sudo lvcreate -L64G NixMain -n cryptRoot
sudo lvcreate -l 100%FREE NixMain -n cryptHome

echo "Encrypting lv ..."
sudo cryptsetup -v -y -c aes-xts-plain64 -s 512 -h sha512 -i 2000 --use-random --label=NIXLUKS_ROOT luksFormat --type luks2 /dev/NixMain/cryptRoot
sudo cryptsetup open --type luks /dev/NixMain/cryptRoot NixRoot
sudo cryptsetup -v -y -c aes-xts-plain64 -s 512 -h sha512 -i 2000 --use-random --label=NIXLUKS_HOME luksFormat --type luks2 /dev/NixMain/cryptHome
sudo cryptsetup open --type luks /dev/NixMain/cryptHome NixHome

echo "Making FileSystem ..."
sudo mkfs.fat  -n NIX_BOOT -F32 "${DISK}"1
sudo mkfs.btrfs -L NIX_ROOT /dev/mapper/NixRoot
sudo mkfs.btrfs -L NIX_HOME /dev/mapper/NixHome
sudo mkswap -L NIX_SWAP /dev/mapper/NixMain-swap

echo "Making btrfs Subvolume ..."
sudo mount /dev/disk/by-label/NIX_ROOT /mnt
sudo btrfs subvolume create /mnt/@
sudo btrfs subvolume create /mnt/@nix
sudo btrfs subvolume create /mnt/@var_log
sudo btrfs subvolume create /mnt/@root_snap
sudo umount /mnt

sudo mount --mkdir /dev/disk/by-label/NIX_HOME /mnt/home
sudo btrfs subvolume create /mnt/@home
sudo btrfs subvolume create /mnt/@home_snap
sudo umount /mnt/home

echo "Mounting Disk ..."
mkdir -p /mnt/{home,nix,var/log,.snapshots}
sudo mount -o umask=0077 /dev/disk/by-label/NIX_BOOT /mnt/boot
sudo swapon -L NIX_SWAP
sudo mount -o rw,ssd,noatime,compress=zstd,discard=async,subvol=@,LABEL=nix_root /dev/disk/by-label/NIX_ROOT /mnt
sudo mount -o rw,ssd,noatime,compress=zstd,discard=async,subvol=@nix,LABEL=nix /dev/disk/by-label/NIX_ROOT /mnt/etx/nixos
sudo mount -o rw,ssd,noatime,compress=zstd,discard=async,subvol=@var_log,LABEL=nix_log /dev/disk/by-label/NIX_ROOT /mnt/var/log
sudo mount -o rw,ssd,noatime,compress=zstd,discard=async,subvol=@root_snap,LABEL=nix_rootsnap /dev/disk/by-label/NIX_ROOT /mnt/.root-snap
sudo mount -o rw,ssd,noatime,compress=zstd,discard=async,subvol=@home,LABEL=nix_home /dev/disk/by-label/NIX_HOME /mnt/home
sudo mount -o rw,ssd,noatime,compress=zstd,discard=async,subvol=@home_snap,LABEL=nix_homesnap /dev/disk/by-label/NIX_HOME /mnt/.home-snap

echo "Finished_"
lsblk