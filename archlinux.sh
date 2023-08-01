#!/bin/bash

# Variables (Please modify according to your needs)
hostname="archlinux"
user="lummyn"
drive="/dev/nvme0n1"  # Change this to your drive, e.g., /dev/nvme0n1
grub="1GiB"
swap_size="6GiB"    # Swap partition size
root_size="66GiB"   # Root partition size
home_size="100%"  # Home partition size (remaining space)

#Update System clock
timedatectl set-timezone America/Lima

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
mkfs.fat -F32 ${drive}p1
mkswap ${drive}p2
mkfs.ext4 ${drive}p3
mkfs.ext4 ${drive}p4

# Mount the partitions

swapon ${drive}p2
mount ${drive}p3 /mnt # For Root
mkdir /mnt/home
mount ${drive}p4 /mnt/home # For Home

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

# Create a new user
echo "Create a new user:"
arch-chroot /mnt useradd -m $user
echo "Set user password:"
arch-chroot /mnt passwd $user
echo 'Allowing members of group "wheel" to use "sudo"...'
arch-chroot /mnt usermod -aG wheel,storage,power $user
arch-chroot /mnt sed -i 's/# %wheel ALL=(ALL:ALL) ALL$/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers 

# Install the bootloader (assuming you're using GRUB)
mkdir -p /mnt/boot/efi # For GRUB UEFI
mount ${drive}p1 /mnt/boot/efi/
arch-chroot /mnt pacman -S grub efibootmgr dosfstools mtools os-prober
arch-chroot /mnt grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Install additional packages (you can customize this according to your needs)
#arch-chroot /mnt pacman -S xorg-server xorg-xinit xterm sddm plasma plasma-desktop plasma-wayland-session firefox dolphin git neovim

# Enable essential services (you can customize this according to your needs)
#arch-chroot /mnt systemctl enable dhcpcd.service NetworkManager.service sddm.service

# Finish and unmount
umount -R /mnt

echo "Installation complete. You can now reboot into your new Arch Linux system."
