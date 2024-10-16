#!/bin/sh

# NOTE This is an attempt to remove the features from install.sh that I don't need and make it more readable as a result

# TODO check preseed first
# TODO detect if preseed is URL and download and point
# TODO check grub password!
# FIXME implement install.sh serial code. Can't see install

# Preseed missing lang, adapter, hostname, country, proxy, root and user passwords, timezone << #FIXME is it getting coppied right?
set -eu

err() {
    printf "\nError: %s.\n" "$1" 1>&2
    exit 1
}

warn() {
    printf "\nWarning: %s.\nContinuing with the default...\n" "$1" 1>&2
    sleep 5
}

command_exists() {
    command -v "$1" > /dev/null 2>&1
}

download() {
    if command_exists wget; then
        wget -O "$2" "$1"
    elif command_exists curl; then
        curl -fL "$1" -o "$2"
    elif command_exists busybox && busybox wget --help > /dev/null 2>&1; then
        busybox wget -O "$2" "$1"
    else
        err 'Cannot find "wget", "curl" or "busybox wget" to download files'
    fi
}

# Default values
kernel_params="console=tty0 console=ttyS0,115200"
suite=bookworm
mirror_protocol=https
mirror_host=deb.debian.org
mirror_directory=/debian
architecture=amd64
daily_d_i=false
efi=
disk=
grub_timeout=5
preseed_file=
firmware=false
power_off=false

# Parse command-line arguments
while [ $# -gt 0 ]; do
    case $1 in
        --preseed)
            preseed_file=$2
            shift
            ;;
        --suite)
            suite=$2
            shift
            ;;
        # Add other options as needed
        *)
            err "Unknown option: \"$1\""
    esac
    shift
done

# Check if preseed file is provided and exists
[ -z "$preseed_file" ] && err "No preseed file specified. Use --preseed option."
[ ! -f "$preseed_file" ] && err "Preseed file not found: $preseed_file"

# Determine if system is EFI
[ -z "$efi" ] && {
    efi=false
    [ -d /sys/firmware/efi ] && efi=true
}

# Installation process
installer_directory="/boot/debian-$suite"
[ "$(id -u)" -ne 0 ] && err 'root privilege is required'
rm -rf "$installer_directory"
mkdir -p "$installer_directory"
cd "$installer_directory"

# Download installation files
base_url="$mirror_protocol://$mirror_host$mirror_directory/dists/$suite/main/installer-$architecture/current/images/netboot/debian-installer/$architecture"
[ "$daily_d_i" = true ] && base_url="https://d-i.debian.org/daily-images/$architecture/daily/netboot/debian-installer/$architecture"

download "$base_url/linux" linux
download "$base_url/initrd.gz" initrd.gz

# Include firmware if specified
[ "$firmware" = true ] && {
    firmware_url="https://cdimage.debian.org/cdimage/unofficial/non-free/firmware/$suite/current/firmware.cpio.gz"
    download "$firmware_url" firmware.cpio.gz
}

# Modify initrd to include preseed
gzip -d initrd.gz
echo "$preseed_file" | cpio -o -H newc -A -F initrd
gzip -1 initrd

# Configure GRUB
mkdir -p /etc/default/grub.d
cat > /etc/default/grub.d/zz-debi.cfg << EOF
GRUB_DEFAULT=debi
GRUB_TIMEOUT=$grub_timeout
GRUB_TIMEOUT_STYLE=menu
EOF

# Update GRUB configuration
if command_exists update-grub; then
    grub_cfg=/boot/grub/grub.cfg
    update-grub
elif command_exists grub2-mkconfig; then
    grub_cfg=/boot/grub2/grub.cfg
    [ -d /sys/firmware/efi ] && grub_cfg=/boot/efi/EFI/*/grub.cfg
    grub2-mkconfig -o "$grub_cfg"
elif command_exists grub-mkconfig; then
    grub_cfg=/boot/grub/grub.cfg
    grub-mkconfig -o "$grub_cfg"
else
    err 'Could not find "update-grub" or "grub2-mkconfig" or "grub-mkconfig" command'
fi

# Add Debian Installer entry to GRUB
cat >> "$grub_cfg" << EOF
menuentry 'Debian Installer' --id debi {
    insmod part_msdos
    insmod part_gpt
    insmod ext2
    insmod xfs
    insmod btrfs
    linux $installer_directory/linux $kernel_params
    initrd $installer_directory/initrd.gz
}
EOF

echo "Installation files prepared. Reboot to start Debian installation."
[ "$power_off" = true ] && poweroff