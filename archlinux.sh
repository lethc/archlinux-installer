#!/bin/bash

# Variables (Please modify according to your needs)
hostname="archlinux"
user="user"
drive="/dev/nvme0n1"  # Change this to your drive, e.g., /dev/nvme0n1
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
echo $hostname > /mnt/etc/hostname

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
arch-chroot /mnt useradd -m $user
echo "Set user password:"
arch-chroot /mnt passwd $user
echo 'Allowing members of group "wheel" to use "sudo"...'
arch-chroot /mnt usermod -aG wheel,storage,power $user
arch-chroot /mnt sed -i 's/# %wheel ALL=(ALL:ALL) ALL$/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers 

# Install the bootloader (assuming you're using GRUB)
echo "##################################################"
echo "##        Installing GRUB bootloader            ##"
echo "##################################################"

mkdir -p /mnt/boot/efi # For GRUB UEFI
mount ${drive}p1 /mnt/boot/efi/
arch-chroot /mnt pacman -S grub efibootmgr dosfstools mtools os-prober
arch-chroot /mnt grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Install additional packages (you can customize this according to your needs)
echo "######################################################"
echo "## Installing display server, DE and audio services ##"
echo "######################################################"
arch-chroot /mnt pacman -S xorg-server xorg-xinit xterm pipewire-alsa pipewire-jack pipewire-pulse alsa-utils gvfs-mtp sddm plasma plasma-desktop plasma-wayland-session

# Install developer apps
#echo "###############################"
#echo "## Installing Developer apps ##"
#echo "###############################"

#arch-chroot /mnt pacman -S nodejs npm python-pip python-pipx go pynvim python-black prettier stylua ripgrep fd gzip  wl-clipboard cliphist unzip deno composer yarn xampp ruby rustup
#arch-chroot /mnt curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install desktop environment
echo "######################################"
echo "##   Installing other applications  ##"
echo "######################################"
arch-chroot /mnt pacman -S zsh dolphin git neovim konsole qutebrowser discover foot man-db mpv yt-dlp zellij newsboat btop gitui packagekit-qt5 flatpak fwupd ark kvantum cronie nautilus telegram-desktop qt5ct zathura zathura-pdf-mupdf firefox
arch-chroot /mnt pacman -S noto-fonts-cjk noto-fonts-emoji noto-fonts ttf-jetbrains-mono-nerd
#arch-chroot /mnt pacman -S zsh-syntax-highlighting zsh-autosuggestions 

# Install yay to Aur
#arch-chroot /mnt git clone https://aur.archlinux.org/yay.git
#arch-chroot /mnt cd yay
#arch-chroot /mnt makepkg -si

#echo "######################################"
#echo "##   Installing  AUR  applications  ##"
#echo "######################################"
#arch-chroot /mnt yay -S ranger-git noto-fonts-emoji-apple lsix nodejs-readability-cli selectdefaultapplication-git apple-fonts nwg-look biber
#arch-chroot /mnt yay -S jdk-lts jdk-lts-doc google-java-format-git python-rpcq rar rofi-lbonn-wayland-git rofi-emoji megacmd

# Zsh dependencies
#arch-chroot /mnt pacman -S zsh-syntax-highlighting zsh-autosuggestions 
#arch-chroot /mnt pacman -S lsd bat
#arch-chroot /mnt yay -S zsh-autocomplete-git zsh-sudo-git zsh-vi-mode

#arch-chroot /mnt pacman -S qt5-graphicaleffects qt5-svg qt5-quickcontrols2 nsxiv
#arch-chroot /mnt yay -S sddm-theme-corners-git
#arch-chroot /mnt mkdir /etc/sddm.conf.d/
#arch-chroot /mnt touch /etc/sddm.conf.d/config 
#arch-chroot /mnt echo "[Theme]" > /etc/sddm.conf.d/config 
#arch-chroot /mnt echo "Current=corners" >> /etc/sddm.conf.d/config 

# Install Hyprland and nvim config dependencies
#echo "##########################################"
#echo "##### Installing neovim dependencies #####"
#echo "##########################################"
#arch-chroot /mnt pacman -S kitty hyprland xdg-desktop-portal-hyprland wofi dunst jq swayidle bc pamixer papirus-icon-theme playerctl grim grimblast slurp wl-clipboard socat swappy nm-connection-editor dictd blueberry acpi swaylock
#arch-chroot /mnt pacman -S xdg-desktop-portal-gtk
#arch-chroot /mnt yay -S  eww-wayland swaylock-effects-git sway-audio-idle-inhibit-git light-git cava cliphist hyprpicker-git wl-clip-persist-git swww

# Enable essential services (you can customize this according to your needs)
echo "###############################"
echo "#####   Enable Services   #####"
echo "###############################"

arch-chroot /mnt systemctl enable dhcpcd.service NetworkManager.service sddm.service
#arch-chroot /mnt echo "export #QT_QPA_PLATFORMTHEME=qt5ct" >> /etc/profile

# Change shell
#arch-chroot /mnt usermod —s /usr/bin/zsh root
#arch-chroot /mnt usermod —s /usr/bin/zsh $user

# Finish and unmount
echo "###############################"
echo "######   unmount disk    ######"
echo "###############################"

umount -R /mnt

echo "###############################################################################"
echo "## Installation complete. You can now reboot into your new Arch Linux system ##"
echo "###############################################################################"
