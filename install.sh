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
sudo mkfs.ext4 -L NIX_ROOT /dev/mapper/NixMain-NixRoot
sudo mkfs.ext4 -L NIX_HOME /dev/mapper/NixMain-NixHome
sudo mkswap -L NIX_SWAP /dev/mapper/NixMain-swap

echo "Mounting Disk ..."
sudo mount /dev/disk/by-label/NIX_ROOT /mnt
sudo mkdir /mnt/boot
sudo mkdir /mnt/home
sudo mount -o umask=0077 /dev/disk/by-label/NIX_BOOT /mnt/boot
sudo mount /dev/disk/by-label/NIX_HOME /mnt/home
sudo swapon -L NIX_SWAP

echo "Finished_"
lsblk