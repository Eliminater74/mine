#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# Prompt for storage drive
lsblk
read -p "Enter the storage drive (e.g. /dev/sda): " DRIVE

# Partition the drive
parted -s "$DRIVE" mklabel gpt
parted -s "$DRIVE" mkpart ESP fat32 1MiB 551MiB
parted -s "$DRIVE" set 1 boot on
parted -s "$DRIVE" mkpart primary btrfs 551MiB 100%

# Format the partitions
mkfs.fat -F32 "${DRIVE}1"
mkfs.btrfs "${DRIVE}2"

# Mount the partitions and create subvolumes
mount "${DRIVE}2" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt
mount -o subvol=@ "${DRIVE}2" /mnt
mkdir /mnt/home
mount -o subvol=@home "${DRIVE}2" /mnt/home
mkdir /mnt/boot
mount "${DRIVE}1" /mnt/boot

# Install the base system
pacstrap /mnt base base-devel linux linux-firmware vim nano btrfs-progs

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Set up swap with zram
echo "zram" > /mnt/etc/modules-load.d/zram.conf
cat <<EOL > /mnt/etc/systemd/system/zram-setup@.service
[Unit]
Description=Set up compressed swap on top of zram
[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c "echo 1 > /sys/class/block/zram\${1}/reset"
ExecStart=/usr/bin/bash -c "echo \$(($(free -b | grep Mem: | awk '{print $2}') * 2)) > /sys/class/block/zram\${1}/disksize"
ExecStart=/sbin/mkswap /dev/zram\${1}
ExecStart=/sbin/swapon /dev/zram\${1}
[Install]
WantedBy=multi-user.target
EOL

# Enter chroot
arch-chroot /mnt

# Set hostname
read -p "Enter hostname: " HOSTNAME
echo "$HOSTNAME" > /etc/hostname

# Set root password
passwd

# Create a new user
read -p "Enter username: " USERNAME
useradd -m -G wheel -s /bin/bash "$USERNAME"
passwd "$USERNAME"
echo "$USERNAME ALL=(ALL) ALL" > /etc/sudoers.d/"$USERNAME"

# Install additional packages
pacman -S plasma-meta sddm sudo git grub grub-btrfs man-db man-pages dolphin-plugins xorg-server xorg-apps

# Prompt for extra packages
read -p "Enter any extra packages to install (space-separated): " EXTRA_PACKAGES
pacman -S $EXTRA_PACKAGES

# Install and configure GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Exit chroot
exit

# Unmount and reboot
umount -R /mnt
reboot
