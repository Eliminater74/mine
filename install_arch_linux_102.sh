#!/bin/bash

# Introduction and Instructions
clear
echo "=============================================="
echo "Arch Linux Installation Script"
echo "=============================================="
echo ""
echo "Welcome to the Arch Linux installation helper!"
echo "This script will guide you through the process of installing Arch Linux with various options."
echo ""
echo "Features:"
echo "- Drive selection"
echo "- Optional Btrfs encryption"
echo "- Btrfs formatting with optional compression"
echo "- Btrfs subvolume creation"
echo "- Essential package installation"
echo "- Network configuration check"
echo "- KDE package installation"
echo "- Additional package installation"
echo "- Custom package installation"
echo "- zRAM setup"
echo "- Pacman repository configuration"
echo ""
echo "Instructions:"
echo "1. Navigate through the menu options."
echo "2. Follow the on-screen prompts."
echo "3. Ensure you have an active internet connection when needed."
echo "4. It's recommended to run this script from a Live Arch Linux environment."
echo ""
echo "Please ensure you have backed up any important data before proceeding."
echo "Proceed at your own risk!"
echo ""
read -p "Press any key to continue to the main menu..."

# Functions
choose_drive() {
    # List available drives and let the user choose
    lsblk
    read -p "Enter the drive you want to install to (e.g. /dev/sda): " DRIVE
}

format_partitions() {
    # Format the selected drive with Btrfs
    read -p "Do you want to enable Btrfs compression? (y/n): " COMPRESS_CHOICE
    if [[ $COMPRESS_CHOICE == "y" ]]; then
        mkfs.btrfs -f --compress=zstd $DRIVE
    else
        mkfs.btrfs -f $DRIVE
    fi
}

create_subvolumes() {
    # Create Btrfs subvolumes
    mount $DRIVE /mnt
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    umount /mnt
}

mount_file_system() {
    # Mount the file system
    mount -o compress=zstd,subvol=@ $DRIVE /mnt
    mkdir /mnt/home
    mount -o compress=zstd,subvol=@home $DRIVE /mnt/home
}

install_essential_packages() {
    # Install essential packages
    pacstrap /mnt base linux linux-firmware
}

configure_fstab() {
    # Generate fstab
    genfstab -U /mnt >> /mnt/etc/fstab
}

chroot_into_system() {
    # Chroot into the new system
    arch-chroot /mnt
}

set_time_zone() {
    # Set the time zone
    ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
    hwclock --systohc
}

localization() {
    # Localization
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
}

network_configuration() {
    # Check for network connection
    if ping -c 1 google.com &> /dev/null; then
        echo "You are connected to the internet."
    else
        echo "You are not connected to the internet. Please check your connection."
        exit 1
    fi
}

install_kde_packages() {
    # Install KDE packages
    pacman -S plasma-meta plasma-wayland-session kde-utilities kde-system dolphin-plugins sddm sddm-kcm kde-graphics ksysguard
}

install_additional_packages() {
    # Install additional packages
    pacman -S btrfs-progs grub grub-btrfs rsync efibootmgr snapper reflector snap-pac zram-generator sudo micro git neofetch zsh man-db man-pages texinfo samba chromium nano
}

install_custom_packages() {
    # Install custom packages
    read -p "Enter a space-separated list of additional packages you want to install: " CUSTOM_PACKAGES
    pacman -S $CUSTOM_PACKAGES
}

setup_zram() {
    # Set up zRAM
    RAM_SIZE=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    ZRAM_SIZE=$((RAM_SIZE / 2))
    echo "zram0" > /etc/modules-load.d/zram.conf
    echo "options zram num_devices=1" > /etc/modprobe.d/zram.conf
    echo 'KERNEL=="zram0", ATTR{disksize}="'$ZRAM_SIZE'K",TAG+="systemd"' > /etc/udev/rules.d/99-zram.rules
}

enable_services() {
    # Enable NetworkManager
    systemctl enable NetworkManager
    echo "NetworkManager service enabled."

    # Check if KDE packages are installed and enable sddm
    if pacman -Qq | grep -q "plasma-meta"; then
        systemctl enable sddm
        echo "sddm service enabled for KDE."
    fi
}

configure_pacman_repos() {
    # Configure pacman repositories
    echo "Available repositories:"
    echo "1) multilib"
    echo "2) multilib-testing"
    echo "3) testing"
    echo "Use space to select multiple repositories."
    read -p "Enter your choice (e.g. 1 3): " REPO_CHOICES
    for choice in $REPO_CHOICES; do
        case $choice in
            1) sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf ;;
            2) sed -i '/\[multilib-testing\]/,/Include/s/^#//' /etc/pacman.conf ;;
            3) sed -i '/\[testing\]/,/Include/s/^#//' /etc/pacman.conf ;;
        esac
    done
}

setup_chaotic_aur() {
    echo "Setting up Chaotic-AUR inside chroot environment..."

    # Check if we're inside chroot
    if [[ $(stat -c %d:%i /) != $(stat -c %d:%i /proc/1/root/.) ]]; then
        echo "You are not inside the chroot environment. Please chroot into the system first."
        return
    fi

    # Import the key
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key 3056513887B78AEB

    # Install the keyring and mirrorlist
    pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

    # Append the repository to pacman.conf
    echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" >> /etc/pacman.conf

    echo "Chaotic-AUR setup complete!"
}

setup_cachyos_repo() {
    echo "Setting up CachyOS repository inside chroot environment..."

    # Check if we're inside chroot
    if [[ $(stat -c %d:%i /) != $(stat -c %d:%i /proc/1/root/.) ]]; then
        echo "You are not inside the chroot environment. Please chroot into the system first."
        return
    fi

    # Install the cachyos keyring
    pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key F3B607488DB35A47
    pacman -U 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-3-1-any.pkg.tar.zst' 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-17-1-any.pkg.tar.zst' 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v3-mirrorlist-17-1-any.pkg.tar.zst' 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v4-mirrorlist-5-1-any.pkg.tar.zst' 'https://mirror.cachyos.org/repo/x86_64/cachyos/pacman-6.0.2-13-x86_64.pkg.tar.zst'

    # Check CPU compatibility
    CPU_COMPATIBILITY=$(/lib/ld-linux-x86-64.so.2 --help | grep supported | grep x86-64-v4)
    if [[ $CPU_COMPATIBILITY == *"supported, searched"* ]]; then
        echo -e "\n[cachyos-v4]\nInclude = /etc/pacman.d/cachyos-v4-mirrorlist" >> /etc/pacman.conf
    fi

    CPU_COMPATIBILITY_V3=$(/lib/ld-linux-x86-64.so.2 --help | grep supported | grep x86-64-v3)
    if [[ $CPU_COMPATIBILITY_V3 == *"supported, searched"* ]]; then
        echo -e "\n[cachyos-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist" >> /etc/pacman.conf
        echo -e "\n[cachyos-core-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist" >> /etc/pacman.conf
        echo -e "\n[cachyos-extra-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist" >> /etc/pacman.conf
    fi

    echo -e "\n[cachyos]\nInclude = /etc/pacman.d/cachyos-mirrorlist" >> /etc/pacman.conf

    echo "CachyOS repository setup complete!"
}

# Main menu
while true; do
    clear
    echo "Arch Linux Installation Menu"
    echo "1) Choose drive"
    echo "2) Format partitions"
    echo "3) Create Btrfs subvolumes"
    echo "4) Mount file system"
    echo "5) Install essential packages"
    echo "6) Configure fstab"
    echo "7) Chroot into system"
    echo "8) Set time zone"
    echo "9) Localization"
    echo "10) Network configuration"
    echo "11) Install KDE packages"
    echo "12) Install additional packages"
    echo "13) Install custom packages"
    echo "14) Setup zRAM"
    echo "15) Enable necessary services"
    echo "16) Configure pacman repositories"
    echo "17) Setup Chaotic-AUR"
    echo "18) Setup CachyOS Repository"
    echo "19) Quit"
    read -p "Enter your choice: " CHOICE
    case $CHOICE in
        1) choose_drive ;;
        2) format_partitions ;;
        3) create_subvolumes ;;
        4) mount_file_system ;;
        5) install_essential_packages ;;
        6) configure_fstab ;;
        7) chroot_into_system ;;
        8) set_time_zone ;;
        9) localization ;;
        10) network_configuration ;;
        11) install_kde_packages ;;
        12) install_additional_packages ;;
         13) install_custom_packages ;;
        14) setup_zram ;;
        15) enable_services ;;
        16) configure_pacman_repos ;;
        17) setup_chaotic_aur ;;
        18) setup_cachyos_repo ;;
        19) echo "Exiting..."; exit ;;
        *) echo "Invalid choice!";;
    esac
    read -p "Press any key to return to the main menu..."
done
