import os
import subprocess


def display_intro():
    os.system('clear')
    print("=" * 50)
    print("   Arch Linux Installation Helper - Python Edition")
    print("=" * 50)
    print("\nWelcome to the Arch Linux installation helper!")
    print("This script provides a guided approach to installing Arch Linux with various customizable options.")
    
    print("\nFeatures:")
    features = [
        "Interactive selection from connected drives.",
        "Option to format partitions with a warning prompt.",
        "Creation of Btrfs subvolumes.",
        "Mounting of the file system.",
        "Installation of essential packages.",
        "Configuration of fstab.",
        "Option to chroot into the system.",
        "Setting of the time zone based on current settings.",
        "Localization setup.",
        "Network configuration options including wired and Wi-Fi.",
        "Installation of KDE packages.",
        "Option to install additional packages.",
        "Custom package installation.",
        "zRAM setup.",
        "Enabling of necessary services.",
        "Configuration of Pacman repositories.",
        "Setup of Chaotic-AUR.",
        "Setup of CachyOS Repository."
    ]
    for feature in features:
        print(f"- {feature}")
    
    print("\nGuidelines:")
    guidelines = [
        "Use the numbers provided to navigate through the menu options.",
        "Follow the on-screen prompts attentively.",
        "Ensure you have an active internet connection when prompted.",
        "It's highly recommended to run this script from a Live Arch Linux environment.",
        "Always backup important data before making changes to drives or partitions."
    ]
    for idx, guideline in enumerate(guidelines, 1):
        print(f"{idx}. {guideline}")
    
    print("\nDisclaimer: Proceed at your own risk!")
    input("\nPress Enter to continue to the main menu...")


def run_command(cmd):
    return subprocess.run(cmd, shell=True, text=True, capture_output=True)


def clear_screen():
    os.system('clear')


def is_inside_chroot():
    return os.stat("/") != os.stat("/proc/1/root/.")


def choose_drive():
    while True:
        clear_screen()  # Clear the screen before displaying the menu
        drives = get_connected_drives()
        if not drives:
            print("No drives detected!")
            return None

        print("Available drives:")
        for idx, drive in enumerate(drives, 1):
            print(f"{idx}. {drive}")

        print(f"{len(drives) + 1}. Return to main menu")

        choice = input("Enter the number of the drive you want to install to or return to the main menu: ")
        if choice.isdigit() and 1 <= int(choice) <= len(drives):
            return drives[int(choice) - 1]
        elif choice == str(len(drives) + 1):
            return None
        else:
            print("Invalid choice. Please select a valid drive number or return to the main menu.")
            input("Press any key to continue...")


def get_connected_drives():
    result = run_command("lsblk -dpno NAME,SIZE,MODEL")
    lines = result.stdout.split("\n")
    drives = []
    for line in lines:
        if line:
            drives.append(line.strip())
    return drives


def format_partitions(drive):
    if not drive:
        print("No drive selected!")
        return

    print(f"\nWARNING: You are about to format the drive {drive}.")
    print("All data on this drive will be permanently lost!")
    confirmation = input("Are you sure you want to proceed? (y/n): ")

    if confirmation.lower() != 'y':
        print("Operation cancelled.")
        return

    choice = input("Do you want to enable Btrfs compression? (y/n): ")
    if choice == "y":
        run_command(f"mkfs.btrfs -f --compress=zstd {drive}")
    else:
        run_command(f"mkfs.btrfs -f {drive}")


def create_subvolumes(drive):
    run_command(f"mount {drive} /mnt")
    run_command("btrfs subvolume create /mnt/@")
    run_command("btrfs subvolume create /mnt/@home")
    run_command("umount /mnt")


def mount_file_system(drive):
    run_command(f"mount -o compress=zstd,subvol=@ {drive} /mnt")
    run_command("mkdir /mnt/home")
    run_command(f"mount -o compress=zstd,subvol=@home {drive} /mnt/home")


def install_essential_packages():
    run_command("pacstrap /mnt base linux linux-firmware")


def configure_fstab():
    run_command("genfstab -U /mnt >> /mnt/etc/fstab")


def chroot_into_system():
    run_command("arch-chroot /mnt")


def set_time_zone():
    # Get the current time zone
    current_timezone = run_command("timedatectl show --property=Timezone --value").stdout.strip()
    
    # Set the time zone based on the current setting
    run_command(f"ln -sf /usr/share/zoneinfo/{current_timezone} /etc/localtime")
    run_command("hwclock --systohc")


def localization():
    run_command('echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen')
    run_command("locale-gen")
    run_command('echo "LANG=en_US.UTF-8" > /etc/locale.conf')


def network_configuration():
    while True:
        clear_screen()  # Clear the screen before displaying the menu
        print("Network Configuration")
        print("-" * 25)
        print("Choose a network connection method:")
        print("1) Wired")
        print("2) Wi-Fi")
        print("3) Check current connection")
        print("4) Return to main menu")
        
        choice = input("Enter your choice: ")
        
        if choice == "1":
            # Assuming the wired connection will be managed by NetworkManager or dhcpcd
            print("Please ensure your ethernet cable is connected.")
            input("Press Enter to continue...")
            
        elif choice == "2":
            ssid = input("Enter the SSID of the Wi-Fi network: ")
            password = input("Enter the password for the Wi-Fi network: ")
            # Connect to the Wi-Fi network using iwctl
            run_command(f"iwctl station wlan0 connect {ssid} --passphrase {password}")
            
        elif choice == "3":
            result = run_command("ping -c 1 google.com")
            if result.returncode == 0:
                print("You are connected to the internet.")
            else:
                print("You are not connected to the internet. Please check your connection.")
                
        elif choice == "4":
            return
        else:
            print("Invalid choice!")


def install_kde_packages():
    run_command("pacman -S plasma-meta plasma-wayland-session kde-utilities kde-system dolphin-plugins sddm sddm-kcm kde-graphics ksysguard")


def install_additional_packages():
    run_command("pacman -S btrfs-progs grub grub-btrfs rsync efibootmgr snapper reflector snap-pac zram-generator sudo micro git neofetch zsh man-db man-pages texinfo samba chromium nano")


def install_custom_packages():
    packages = input(
        "Enter a space-separated list of additional packages you want to install: ")
    run_command(f"pacman -S {packages}")


def setup_zram():
    ram_size = int(run_command(
        "grep MemTotal /proc/meminfo | awk '{print $2}'").stdout)
    zram_size = ram_size // 2
    run_command(f'echo "zram0" > /etc/modules-load.d/zram.conf')
    run_command(f'echo "options zram num_devices=1" > /etc/modprobe.d/zram.conf')
    run_command(
        f'echo \'KERNEL=="zram0", ATTR{{disksize}}="{zram_size}K",TAG+="systemd"\' > /etc/udev/rules.d/99-zram.rules')


def enable_services():
    run_command("systemctl enable NetworkManager")
    print("NetworkManager service enabled.")
    result = run_command("pacman -Qq | grep -q 'plasma-meta'")
    if result.returncode == 0:
        run_command("systemctl enable sddm")
        print("sddm service enabled for KDE.")


def configure_pacman_repos():
    print("Available repositories:")
    print("1) multilib")
    print("2) multilib-testing")
    print("3) testing")
    choices = input(
        "Use space to select multiple repositories. Enter your choice (e.g. 1 3): ").split()
    for choice in choices:
        if choice == "1":
            run_command(
                "sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf")
        elif choice == "2":
            run_command(
                "sed -i '/\[multilib-testing\]/,/Include/s/^#//' /etc/pacman.conf")
        elif choice == "3":
            run_command(
                "sed -i '/\[testing\]/,/Include/s/^#//' /etc/pacman.conf")


def setup_chaotic_aur():
    print("Setting up Chaotic-AUR inside chroot environment...")
    if not is_inside_chroot():
        print("You are not inside the chroot environment. Please chroot into the system first.")
        return
    run_command(
        "pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com")
    run_command("pacman-key --lsign-key 3056513887B78AEB")
    run_command("pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'")
    run_command(
        'echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" >> /etc/pacman.conf')
    print("Chaotic-AUR setup complete!")


def setup_cachyos_repo():
    print("Setting up CachyOS repository inside chroot environment...")
    if not is_inside_chroot():
        print("You are not inside the chroot environment. Please chroot into the system first.")
        return
    run_command(
        "pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com")
    run_command("pacman-key --lsign-key F3B607488DB35A47")
    run_command("pacman -U 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-3-1-any.pkg.tar.zst' 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-17-1-any.pkg.tar.zst' 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v3-mirrorlist-17-1-any.pkg.tar.zst' 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v4-mirrorlist-5-1-any.pkg.tar.zst' 'https://mirror.cachyos.org/repo/x86_64/cachyos/pacman-6.0.2-13-x86_64.pkg.tar.zst'")

    cpu_compatibility = run_command(
        "/lib/ld-linux-x86-64.so.2 --help | grep supported | grep x86-64-v4")
    if "supported, searched" in cpu_compatibility.stdout:
        run_command(
            'echo -e "\n[cachyos-v4]\nInclude = /etc/pacman.d/cachyos-v4-mirrorlist" >> /etc/pacman.conf')

    cpu_compatibility_v3 = run_command(
        "/lib/ld-linux-x86-64.so.2 --help | grep supported | grep x86-64-v3")
    if "supported, searched" in cpu_compatibility_v3.stdout:
        run_command(
            'echo -e "\n[cachyos-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist" >> /etc/pacman.conf')
        run_command(
            'echo -e "\n[cachyos-core-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist" >> /etc/pacman.conf')
        run_command(
            'echo -e "\n[cachyos-extra-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist" >> /etc/pacman.conf')

    run_command(
        'echo -e "\n[cachyos]\nInclude = /etc/pacman.d/cachyos-mirrorlist" >> /etc/pacman.conf')
    print("CachyOS repository setup complete!")


def main():
    while True:
        clear_screen()
        print("Arch Linux Installation Menu")
        print("1) Choose drive")
        print("2) Format partitions")
        print("3) Create Btrfs subvolumes")
        print("4) Mount file system")
        print("5) Install essential packages")
        print("6) Configure fstab")
        print("7) Chroot into system")
        print("8) Set time zone")
        print("9) Localization")
        print("10) Network configuration")
        print("11) Install KDE packages")
        print("12) Install additional packages")
        print("13) Install custom packages")
        print("14) Setup zRAM")
        print("15) Enable necessary services")
        print("16) Configure pacman repositories")
        print("17) Setup Chaotic-AUR")
        print("18) Setup CachyOS Repository")
        print("19) Quit")
        choice = input("Enter your choice: ")

        if choice == "1":
            drive = choose_drive()
        elif choice == "2":
            format_partitions(drive)
        elif choice == "3":
            create_subvolumes(drive)
        elif choice == "4":
            mount_file_system(drive)
        elif choice == "5":
            install_essential_packages()
        elif choice == "6":
            configure_fstab()
        elif choice == "7":
            chroot_into_system()
        elif choice == "8":
            set_time_zone()
        elif choice == "9":
            localization()
        elif choice == "10":
            network_configuration()
        elif choice == "11":
            install_kde_packages()
        elif choice == "12":
            install_additional_packages()
        elif choice == "13":
            install_custom_packages()
        elif choice == "14":
            setup_zram()
        elif choice == "15":
            enable_services()
        elif choice == "16":
            configure_pacman_repos()
        elif choice == "17":
            setup_chaotic_aur()
        elif choice == "18":
            setup_cachyos_repo()
        elif choice == "19":
            print("Exiting...")
            break
        else:
            print("Invalid choice!")
        input("Press any key to return to the main menu...")


if __name__ == "__main__":
    display_intro()
    main()
