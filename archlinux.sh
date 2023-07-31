#!/bin/bash

# Variables (Please modify according to your needs)
hostname="archlinux"
drive="/dev/nvme0n1"  # Change this to your drive, e.g., /dev/nvme0n1
grub="1GiB"
swap_size="4GiB"    # Swap partition size
root_size="50GiB"   # Root partition size
home_size="100%"  # Home partition size (remaining space)

# Ensure we have the latest package list
pacman -Sy

# Partition the drive using parted
parted $drive mklabel gpt
parted $drive mkpart primary fat32 1MiB $grub  # For GRUB UEFI
parted $drive mkpart primary linux-swap $grub $swap_size # For Swap
parted $drive mkpart primary ext4 $swap_size $root_size # For Root
parted $drive mkpart primary ext4 $root_size $home_size # For Home
parted $drive set 1 esp on

# Format the partitions
mkswap ${drive}1
mkfs.ext4 ${drive}2
mkfs.ext4 ${drive}3

# Mount the partitions
mount ${drive}2 /mnt
mkdir /mnt/home
mount ${drive}3 /mnt/home
swapon ${drive}1

# Install Arch Linux base system
pacstrap /mnt base base-devel linux-lts linux-lts-headers linux-firmware amd-ucode nano vim git sudo networkmanager dhcpcd pulseaudio bluez wpa_supplicant 
# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Set the timezone (you can change this according to your location)
arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Lima /etc/localtime
arch-chroot /mnt hwclock --systohc

# Set the locale (uncomment the desired locale if you want to use other than en_US.UTF-8)
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
echo "es_ES.UTF-8 UTF-8" >> /mnt/etc/locale.gen
# echo "fr_FR.UTF-8 UTF-8" >> /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf

# Set the hostname (change 'archlinux' to your preferred hostname)
echo $hostname > /mnt/etc/hostname

# Set the hosts file
echo "127.0.0.1 localhost" >> /mnt/etc/hosts
echo "::1 localhost" >> /mnt/etc/hosts
echo "127.0.1.1 ${hostname}.localdomain localhost" >> /mnt/etc/hosts

# Set the root password
echo "Set root password:"
arch-chroot /mnt passwd

# Install the bootloader (assuming you're using GRUB)
arch-chroot /mnt pacman -S grub efibootmgr dosfstools mtools
arch-chroot /mnt grub-install --target=x86_64-efi --bootloader-id=arch_grub --recheck
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Install additional packages (you can customize this according to your needs)
# arch-chroot /mnt pacman -S <package1> <package2> ...

# Enable essential services (you can customize this according to your needs)
# arch-chroot /mnt systemctl enable <service1> <service2> ...

# Finish and unmount
umount -R /mnt

echo "Installation complete. You can now reboot into your new Arch Linux system."