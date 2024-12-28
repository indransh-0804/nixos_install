#!/usr/bin/env bash

set -e  # Exit on error
set -x  # Print commands as they run (useful for debugging)

# Variables
DISK="/dev/sda"      # Replace with your target disk
HOSTNAME="mynix"  # Change to your desired hostname

#script begins ...
sudo cryptsetup -v -y -c aes-xts-plain64 -s 512 -h sha512 -i 2000 --use-random --label=NIX_LUKS luksFormat --type luks2 "${DISK}2"
sudo cryptsetup open --type luks "${DISK}"2 cryptMain
sudo pvcreate /dev/mapper/cryptMain
sudo vgcreate Main /dev/mapper/cryptMain
sudo lvcreate -L2G Main -n swap
sudo lvcreate -L64G Main -n root
sudo lvcreate -l 100%FREE Main -n home
sudo mkfs.fat  -n NIX_BOOT -F32 "${DISK}"1
sudo mkfs.ext4 -L NIX_ROOT /dev/mapper/Main-root
sudo mkfs.ext4 -L NIX_HOME /dev/mapper/Main-home
sudo mkswap -L NIX_SWAP /dev/mapper/Main-swap
sudo mount /dev/disk/by-label/NIX_ROOT /mnt
sudo mkdir /mnt/boot
sudo mkdir /mnt/home
sudo mount -o umask=0077 /dev/disk/by-label/NIX_BOOT /mnt/boot
sudo mount /dev/disk/by-label/NIX_HOME /mnt/home
sudo swapon -L NIX_SWAP
lsblk