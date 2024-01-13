#!/bin/bash

# Variables (Please modify according to your needs)
hostname="archlinux"
user="user"
drive="nvme0n1"  # Change this to your drive (e.g., sda/nvme0n1)
grub="1GiB"
swap_size="6GiB"    # Swap partition size
root_size="86GiB"   # Root partition size
home_size="100%"  # Home partition size (remaining space)

#Update System clock
timedatectl set-timezone America/Lima

# Ensure we have the latest package list
pacman -Sy

# Partition the drive using parted
echo "##########################################"
echo "##        Partitioning the drive       ##"
echo "##########################################"

# Handle the difference between partitioning naming schemes (sda1/nvme0n1p1)
if [[ "$drive" == nvme* ]]; then
  disk_path="/dev/$drive"
  efi_partition_path="/dev/${drive}p1"
  swap_partition_path="/dev/${drive}p2"
  root_partition_path="/dev/${drive}p3"
  home_partition_path="/dev/${drive}p4"
else
  disk_path="/dev/$drive"
  efi_partition_path="/dev/${drive}1"
  swap_partition_path="/dev/${drive}2"
  root_partition_path="/dev/${drive}3"
  home_partition_path="/dev/${drive}4"
fi

parted "$disk_path" mklabel gpt
parted "$disk_path" mkpart primary fat32 1MiB "$grub"  # For GRUB UEFI
parted "$disk_path" mkpart primary linux-swap "$grub" "$swap_size" # For Swap
parted "$disk_path" mkpart primary ext4 "$swap_size" "$root_size" # For Root
parted "$disk_path" mkpart primary ext4 "$root_size" "$home_size" # For Home
parted "$dish_path" set 1 esp on

# Format the partitions
mkfs.fat -F32 "$efi_partition_path"
mkswap "$swap_partition_path"
mkfs.ext4 "$root_partition_path"
mkfs.ext4 "$home_partition_path"

# Mount the partitions

swapon "$swap_partition_path"
mount "$root_partition_path" /mnt # For Root
mkdir /mnt/home
mount "$home_partition_path" /mnt/home # For Home

# Install Arch Linux base system
echo "##########################################"
echo "##  Installing Arch Linux base system   ##"
echo "##########################################"
pacstrap /mnt base base-devel linux-lts linux-lts-headers linux-firmware amd-ucode nano vim git sudo networkmanager dhcpcd bluez wpa_supplicant 
# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Set the timezone (you can change this according to your location)
arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Lima /etc/localtime
arch-chroot /mnt hwclock --systohc

# Set the locale (uncomment the desired locale if you want to use other than en_US.UTF-8)
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
echo "es_ES.UTF-8 UTF-8" >> /mnt/etc/locale.gen
echo "en_GB.UTF-8 UTF-8" >> /mnt/etc/locale.gen
# echo "fr_FR.UTF-8 UTF-8" >> /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=en_GB.UTF-8" > /mnt/etc/locale.conf

# Set the hostname (change 'archlinux' to your preferred hostname)
echo "$hostname" > /mnt/etc/hostname

# Set the hosts file
echo "127.0.0.1 localhost" >> /mnt/etc/hosts
echo "::1 localhost" >> /mnt/etc/hosts
echo "127.0.1.1 ${hostname}.localdomain localhost" >> /mnt/etc/hosts

# Set the root password
echo "###############################"
echo "##     Set root password     ##"
echo "###############################"
echo "Set root password:"
arch-chroot /mnt passwd

# Create a new user
echo "##################################################"
echo "##       Creating user and password             ##"
echo "##################################################"

echo "Create a new user:"
arch-chroot /mnt useradd -m "$user"
echo "Set user password:"
arch-chroot /mnt passwd "$user"
echo 'Allowing members of group "wheel" to use "sudo"...'
arch-chroot /mnt usermod -aG wheel,storage,power "$user"
arch-chroot /mnt sed -i 's/# %wheel ALL=(ALL:ALL) ALL$/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers 

# Install the bootloader (assuming you're using GRUB)
echo "##################################################"
echo "##        Installing GRUB bootloader            ##"
echo "##################################################"

mkdir -p /mnt/boot/efi # For GRUB UEFI
mount "$efi_partition_path" /mnt/boot/efi/
arch-chroot /mnt pacman -S grub efibootmgr dosfstools mtools os-prober
arch-chroot /mnt grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Install additional packages (you can customize this according to your needs)
echo "######################################################"
echo "## Installing display server, DE and audio services ##"
echo "######################################################"
arch-chroot /mnt pacman -S xorg-server xorg-xinit xterm pipewire-alsa pipewire-jack pipewire-pulse alsa-utils gvfs-mtp sddm plasma plasma-desktop plasma-wayland-session

# Install desktop environment
echo "######################################"
echo "##   Installing other applications  ##"
echo "######################################"

arch-chroot /mnt pacman -S zsh dolphin git neovim konsole qutebrowser discover foot man-db mpv yt-dlp zellij newsboat btop gitui packagekit-qt5 flatpak fwupd ark kvantum cronie nautilus telegram-desktop qt5ct zathura zathura-pdf-mupdf firefox gnome-sound-recorder gnome-clocks pavucontrol qalculate-gtk imv fcitx5 fcitx5-configtool fcitx5-gtk fcitx5-qt fcitx5-mozc fcitx5-hangul fcitx5-chinese-addons gnome-keyring snapshot loupe brightnessctl gnome-bluetooth-3.0 sassc wl-clipboard neofetch
arch-chroot /mnt pacman -S noto-fonts-cjk noto-fonts-emoji noto-fonts ttf-jetbrains-mono-nerd ttf-roboto-mono-nerd

# Enable essential services (you can customize this according to your needs)
echo "###############################"
echo "#####   Enable Services   #####"
echo "###############################"

arch-chroot /mnt systemctl enable dhcpcd.service NetworkManager.service sddm.service cronie.service
# Finish and unmount
echo "###############################"
echo "######   unmount disk    ######"
echo "###############################"

umount -R /mnt

echo "###############################################################################"
echo "## Installation complete. You can now reboot into your new Arch Linux system ##"
echo "###############################################################################"
