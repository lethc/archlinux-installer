#!/bin/bash

# Variables (modify according to your needs)
hostname="archlinux"
user="user"
drive="nvme0n1"          # Example: sda / nvme0n1
grub="500MiB"
swap_size="6GiB"

# -----------------------------
# System clock
# -----------------------------
timedatectl set-timezone America/Lima
timedatectl set-ntp true

# -----------------------------
# Update package list
# -----------------------------
pacman -Sy

echo "##########################################"
echo "##        Partitioning the drive        ##"
echo "##########################################"

# -----------------------------
# Partition naming
# -----------------------------
if [[ "$drive" == nvme* ]]; then
  disk_path="/dev/$drive"
  efi_partition_path="/dev/${drive}p1"
  swap_partition_path="/dev/${drive}p2"
  root_partition_path="/dev/${drive}p3"
else
  disk_path="/dev/$drive"
  efi_partition_path="/dev/${drive}1"
  swap_partition_path="/dev/${drive}2"
  root_partition_path="/dev/${drive}3"
fi

# -----------------------------
# Create GPT partition table
# -----------------------------
sgdisk -o "$disk_path"

# EFI partition
sgdisk -n 1:1MiB:+${grub} -t 1:EF00 "$disk_path"

# Swap partition
sgdisk -n 2:0:+${swap_size} -t 2:8200 "$disk_path"

# Root partition uses all remaining space
sgdisk -n 3:0:0 -t 3:8300 "$disk_path"

# Reload partition table
partprobe "$disk_path"

# -----------------------------
# Format partitions
# -----------------------------
mkfs.fat -F32 "$efi_partition_path"
mkswap "$swap_partition_path"
mkfs.ext4 "$root_partition_path"

# -----------------------------
# Mount partitions
# -----------------------------
swapon "$swap_partition_path"

mount "$root_partition_path" /mnt

mkdir -p /mnt/boot/efi
mount "$efi_partition_path" /mnt/boot/efi

# -----------------------------
# Install base system
# -----------------------------
echo "##########################################"
echo "##  Installing Arch Linux base system   ##"
echo "##########################################"

pacstrap /mnt base base-devel dkms linux linux-headers linux-firmware amd-ucode nano vim git sudo networkmanager dhcpcd bluez bluez-utils wpa_supplicant

# -----------------------------
# Generate fstab
# -----------------------------
genfstab -U /mnt >> /mnt/etc/fstab

# -----------------------------
# Timezone
# -----------------------------
arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Lima /etc/localtime
arch-chroot /mnt hwclock --systohc

# -----------------------------
# Locale
# -----------------------------
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
echo "es_ES.UTF-8 UTF-8" >> /mnt/etc/locale.gen
echo "en_GB.UTF-8 UTF-8" >> /mnt/etc/locale.gen

arch-chroot /mnt locale-gen

echo "LANG=en_GB.UTF-8" > /mnt/etc/locale.conf

# -----------------------------
# Hostname
# -----------------------------
echo "$hostname" > /mnt/etc/hostname

cat >> /mnt/etc/hosts <<EOF
127.0.0.1 localhost
::1 localhost
127.0.1.1 ${hostname}.localdomain ${hostname}
EOF

# -----------------------------
# Root password
# -----------------------------
echo "###############################"
echo "##     Set root password     ##"
echo "###############################"

arch-chroot /mnt passwd

# -----------------------------
# User creation
# -----------------------------
echo "##################################################"
echo "##       Creating user and password             ##"
echo "##################################################"

arch-chroot /mnt useradd -m -G wheel,storage,power "$user"
arch-chroot /mnt passwd "$user"

# Enable sudo for wheel
arch-chroot /mnt sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# -----------------------------
# Bootloader
# -----------------------------
echo "##################################################"
echo "##        Installing GRUB bootloader            ##"
echo "##################################################"

arch-chroot /mnt pacman -S --noconfirm grub efibootmgr dosfstools mtools os-prober ntfs-3g

arch-chroot /mnt grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# -----------------------------
# Desktop / display / audio
# -----------------------------
echo "######################################################"
echo "## Installing display server, DE and audio services ##"
echo "######################################################"

arch-chroot /mnt pacman -S --noconfirm \
hyprland cpio meson cmake \
xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xdg-desktop-portal-kde \
hyprlock hypridle hyprpicker \
pipewire-alsa pipewire-jack pipewire-pulse alsa-utils \
gvfs-mtp sddm breeze kitty foot foot-terminfo

# -----------------------------
# Applications
# -----------------------------
echo "######################################"
echo "##   Installing other applications  ##"
echo "######################################"

arch-chroot /mnt pacman -S --noconfirm \
zsh dolphin \
tesseract-data-eng tesseract-data-spa tesseract-data-kor \
tesseract git neovim qutebrowser man-db mpv yt-dlp zellij newsboat \
btop gitui flatpak fwupd ark kvantum kvantum-qt5 cronie nautilus \
telegram-desktop zathura zathura-pdf-mupdf firefox \
gnome-sound-recorder gnome-clocks pavucontrol qalculate-gtk imv \
fcitx5 fcitx5-configtool fcitx5-gtk fcitx5-qt fcitx5-mozc \
fcitx5-hangul fcitx5-chinese-addons gnome-keyring snapshot loupe \
brightnessctl gnome-bluetooth-3.0 wl-clipboard totem evince \
evince-lib-docs ffmpegthumbs kdegraphics-thumbnailers \
kimageformats kimageformats5 \
noto-fonts-cjk noto-fonts ttf-jetbrains-mono-nerd

# -----------------------------
# Enable services
# -----------------------------
echo "###############################"
echo "#####   Enable Services   #####"
echo "###############################"

arch-chroot /mnt systemctl enable NetworkManager.service
arch-chroot /mnt systemctl enable sddm.service
arch-chroot /mnt systemctl enable cronie.service
arch-chroot /mnt systemctl enable bluetooth.service

# -----------------------------
# User directories
# -----------------------------
arch-chroot /mnt pacman -S --noconfirm xdg-user-dirs
arch-chroot /mnt sudo -u "$user" xdg-user-dirs-update

# -----------------------------
# Clone config
# -----------------------------
arch-chroot /mnt sudo -u "$user" git clone https://github.com/lethc/hyprland-dotfiles.git "/home/$user/.config/hypr"

# -----------------------------
# Finish
# -----------------------------
echo "###############################"
echo "######   unmount disk    ######"
echo "###############################"

umount -R /mnt

echo "###############################################################################"
echo "## Installation complete. You can now reboot into your new Arch Linux system ##"
echo "###############################################################################"