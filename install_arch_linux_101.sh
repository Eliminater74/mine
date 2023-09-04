#!/bin/bash

# Function to display the main menu
main_menu() {
    clear
    echo "===================================="
    echo " Arch Linux Installation Script"
    echo "===================================="
    echo "1. Keyboard and font"
    echo "2. Verify boot mode"
    echo "3. Connect to internet"
    echo "4. Check network connection"
    echo "5. Update system clock"
    echo "6. Choose storage drive for installation"
    echo "7. Partitioning"
    echo "8. Btrfs setup (with optional encryption)"
    echo "9. Set root password"
    echo "10. Create a user with superuser privileges"
    echo "11. Exit"
}

# Variable to check if encryption was chosen
encryption_chosen=false

# Function to choose storage drive
choose_storage_drive() {
    clear
    echo "Available storage drives:"

    # Get a list of available drives and display them with a number
    drives=($(lsblk -d -p -n -l -o NAME))
    for i in "${!drives[@]}"; do
        size=$(lsblk -d -p -n -l -o SIZE ${drives[$i]})
        model=$(lsblk -d -p -n -l -o MODEL ${drives[$i]})
        echo "$((i+1)). ${drives[$i]} $size $model"
    done

    # Prompt the user to select a drive by number
    read -p "Choose a drive by number: " drive_num
    if [[ $drive_num -ge 1 && $drive_num -le ${#drives[@]} ]]; then
        export disk="${drives[$((drive_num-1))]}"
        echo "You selected $disk for installation."
    else
        echo "Invalid selection."
    fi
}

# Function to check network connection
check_network() {
    if ping -c 1 8.8.8.8 &> /dev/null; then
        echo "Network is connected."
    else
        echo "Network is not connected."
        echo "1. Connect using wired network"
        echo "2. Connect using wireless network"
        echo -n "Choose an option [1-2]: "
        read net_choice
        case $net_choice in
            1)
                dhcpcd
                ;;
            2)
                wifi-menu
                ;;
            *)
                echo "Invalid choice."
                ;;
        esac
    fi
}

# Function to partition the selected drive
partition_drive() {
    clear
    echo "Partitioning $disk..."
    # This is a basic partitioning scheme. Adjust as needed.
    parted $disk mklabel gpt
    parted $disk mkpart primary 512MiB 100%
    parted $disk mkpart ESP fat32 1MiB 512MiB
    parted $disk set 2 boot on
}

# Function for Btrfs setup with optional encryption
btrfs_setup() {
    clear
    read -p "Do you want to encrypt the partition? (y/n): " enc_choice
    if [[ $enc_choice == "y" || $enc_choice == "Y" ]]; then
        echo "Setting up encryption..."
        cryptsetup luksFormat ${disk}2
        cryptsetup open ${disk}2 cryptroot
        mkfs.btrfs /dev/mapper/cryptroot
        mount /dev/mapper/cryptroot /mnt
    else
        mkfs.btrfs ${disk}2
        mount ${disk}2 /mnt
    fi
}

# Function to set root password
set_root_password() {
    clear
    passwd
}

# Function to create a user with superuser privileges
create_superuser() {
    clear
    read -p "Enter new username: " username
    useradd -m -G wheel -s /bin/bash $username
    passwd $username
    echo "$username ALL=(ALL) ALL" >> /etc/sudoers
}

# Function to set up zram for swap
setup_zram_swap() {
    clear
    echo "Setting up zram for swap..."

    # Calculate half of the total RAM size in bytes
    total_ram=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    half_ram=$((total_ram * 1024 / 2))

    modprobe zram
    echo zstd > /sys/block/zram0/comp_algorithm
    echo $half_ram > /sys/block/zram0/disksize
    mkswap --label zram0 /dev/zram0
    swapon --priority 100 /dev/zram0
    echo "Zram for swap has been set up!"
}

while true; do
    clear
    echo "Arch Linux Installation Menu"
    echo "1) Update System Clock"
    echo "2) Partition Disk"
    echo "3) Format Partitions"
    echo "4) Mount File System"
    echo "5) Install Essential Packages"
    echo "6) Configure Fstab"
    echo "7) Chroot into new system"
    echo "8) Set Time Zone"
    echo "9) Localization"
    echo "10) Network Configuration"
    echo "11) Setup zram for swap"
    echo "12) Quit"
    read -p "Enter your choice: " choice

    case $choice in
        1) update_system_clock ;;
        2) partition_disk ;;
        3) format_partitions ;;
        4) mount_file_system ;;
        5) install_essential_packages ;;
        6) configure_fstab ;;
        7) chroot_into_system ;;
        8) set_time_zone ;;
        9) localization ;;
        10) network_configuration ;;
        11) setup_zram_swap ;;
        12) break ;;
        *) echo "Invalid option!" ;;
    esac
    read -p "Press any key to return to the menu..."
done
