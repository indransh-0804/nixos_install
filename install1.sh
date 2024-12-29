#!/usr/bin/env bash

# Variables
DISK="/dev/sda"      # Replace with your target disk

#script

echo "The Script Begins..."
set -e  # Exit on error
set -x  # Print commands as they run (useful for debugging)

parted "$DISK" -- mklabel gpt
parted "$DISK" -- mkpart primary 512MiB 100%
parted "$DISK" -- mkpart ESP fat32 1MiB 512 MiB
parted "$DISK" -- set 2 boot on

echo "Creating LVM ..."
sudo pvcreate "${DISK}"2
sudo vgcreate NixMain "${DISK}"2
sudo lvcreate -L8G NixMain -n swap
sudo lvcreate -L64G NixMain -n cryptRoot
sudo lvcreate -l 100%FREE NixMain -n cryptHome

echo "Encrypting lv ..."
sudo cryptsetup -v -y -c aes-xts-plain64 -s 512 -h sha512 -i 2000 --use-random --label=NIXLUKS_ROOT luksFormat --type luks2 /dev/NixMain/cryptRoot
sudo cryptsetup -v -y -c aes-xts-plain64 -s 512 -h sha512 -i 2000 --use-random --label=NIXLUKS_HOME luksFormat --type luks2 /dev/NixMain/cryptHome
sudo cryptsetup open --type luks /dev/NixMain/cryptRoot NixRoot
sudo cryptsetup open --type luks /dev/NixMain/cryptHome NixHome

echo "Making FileSystem ..."
sudo mkfs.fat  -n NIX_BOOT -F32 "${DISK}"1
sudo mkswap -L NIX_SWAP /dev/mapper/NixMain-swap
sudo mkfs.btrfs -L NIX_ROOT /dev/mapper/NixRoot
sudo mkfs.btrfs -L NIX_HOME /dev/mapper/NixHom

echo "Making btrfs Subvolume ..."
sudo mount -t btrfs /dev/disk/by-label/NIX_ROOT /mnt
cd /mnt
sudo btrfs subvolume create @
sudo btrfs subvolume create @nix
sudo btrfs subvolume create @log
sudo btrfs subvolume create @.snap
cd 

sudo mount -t btrfs --mkdir /dev/disk/by-label/NIX_HOME /mnt/home
cd /mnt/home
sudo btrfs subvolume create @home
cd
sudo umount -R /mnt

echo "Mounting Disk ..."
sudo mount -o umask=0077 --mkdir /dev/disk/by-label/NIX_BOOT /mnt/boot
sudo swapon -L NIX_SWAP
sudo mount -t btrfs -o rw,ssd,noatime,compress=zstd,discard=async,subvol=@ --mkdir /dev/disk/by-label/NIX_ROOT /mnt
sudo mount -t btrfs -o rw,ssd,noatime,compress=zstd,discard=async,subvol=@nix --mkdir /dev/disk/by-label/NIX_ROOT /mnt/etc/nix
sudo mount -t btrfs -o rw,ssd,noatime,compress=zstd,discard=async,subvol=@log --mkdir /dev/disk/by-label/NIX_ROOT /mnt/var/log
sudo mount -t btrfs -o rw,ssd,noatime,compress=zstd,discard=async,subvol=@.snap --mkdir /dev/disk/by-label/NIX_ROOT /mnt/.snap
sudo mount -t btrfs -o rw,ssd,noatime,compress=zstd,discard=async,subvol=@home --mkdir /dev/disk/by-label/NIX_HOME /mnt/home

echo "Finished_"
lsblk

