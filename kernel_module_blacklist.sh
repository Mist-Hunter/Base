#!/usr/bin/env bash
set -euo pipefail

MOD_BLACKLIST="/etc/modprobe.d/10-kernel-module-blacklist.conf"

# ───────────────────────────────────────────────
# Define module buckets
# ───────────────────────────────────────────────

# Filesystem-related modules (legacy/unused filesystems, CD/floppy)
declare -A FS_MODULES=(
    [ahci]="AHCI SATA host controller"
    [ata_generic]="Generic ATA host controllers"
    [ata_piix]="Intel PIIX/ICH ATA host controllers"
    [cdrom]="CD-ROM drive support"
    [floppy]="Floppy disk support"
    [freevxfs]="Freevxfs filesystem"
    [hfs]="HFS filesystem"
    [hfsplus]="HFS+ filesystem"
    [jffs2]="JFFS2 filesystem"
    [squashfs]="SquashFS filesystem"
    [udf]="UDF filesystem"
    [libata]="SCSI-to-ATA translation layer"
    [sr_mod]="SCSI CD-ROM support"
)

# FIXME the modules below break booting.
# [vfat]="FAT filesystem (vfat)"
# [fat]="FAT filesystem core"
# [nls_ascii]="FAT NLS ascii"
# [nls_cp437]="FAT NLS cp437"

# Network-related modules
declare -A NET_MODULES=(
    [cfg80211]="IEEE 802.11 wireless stack"
    [dccp]="Datagram Congestion Control Protocol"
    [rds]="Reliable Datagram Sockets"
    [sctp]="Stream Control Transmission Protocol"
    [tipc]="Transparent IPC"
    [8021q]="VLAN 802.1q tagging"
    [garp]="GARP protocol"
    [stp]="Spanning Tree Protocol"
    [mrp]="MRP protocol"
    [llc]="802.2 LLC"
)

# FIXME breaks ipset
# [nfnetlink]="Netfilter netlink interface"

# USB-related modules
declare -A USB_MODULES=(
    [ehci]="USB EHCI host controller"
    [ehci_hcd]="EHCI USB host controller"
    [ehci_pci]="EHCI USB PCI driver"
    [uhci_hcd]="UHCI USB 1.1 controller"
    [usb_common]="USB common functions"
    [usb_storage]="USB mass storage"
    [usbcore]="USB core"
    [hcd]="Host Controller Driver"
    [usd]="USB device support"
)

# DRM / graphics modules
declare -A DRM_MODULES=(
    [drm]="Direct Rendering Manager core"
    [bochs_drm]="Bochs emulator DRM"
)

# Input and peripheral modules
declare -A INPUT_MODULES=(
    [joydev]="Joystick input"
    [psmouse]="PS/2 mouse"
    [pcspkr]="PC speaker"
    [serio_raw]="Raw serio interface"
    [evdev]="Input event interface"
    [button]="ACPI button events"
)

# Platform, chipset, watchdog, and bus modules
declare -A PLATFORM_MODULES=(
    [iTCO_wdt]="Intel TCO Watchdog Timer"
    [i2c_i801]="Intel SMBus controller driver"
    [i2c_smbus]="SMBus access through I2C subsystem"
    [pciehp]="PCI hotplug controller"
    [shpchp]="PCI hotplug controller"
    [lpc_ich]="LPC ICH chipset interface"
)

# Miscellaneous modules
declare -A MISC_MODULES=(
    [snd_hda_intel]="Intel HD Audio"
    [binfmt_misc]="Binfmt interpreter"
    [configfs]="Kernel configfs"
    [autofs4]="Automounter"
)

# ───────────────────────────────────────────────
# Utility: blacklist a single module
# ───────────────────────────────────────────────
blacklist_module() {
    local mod="$1" desc="$2"

    if ! modinfo -n "$mod" &>/dev/null; then
        echo "⏭  $mod not found, skipping."
        return
    fi

    if modinfo -F builtin "$mod" 2>/dev/null | grep -q '^y$'; then
        echo "⏭  $mod is built-in, skipping."
        return
    fi

    if grep -qw "$mod" "$MOD_BLACKLIST"; then
        echo "⏭  $mod already blacklisted."
        return
    fi

    modprobe -r "$mod" 2>/dev/null || true

    printf "# %s\nblacklist %s\ninstall %s /bin/true\n\n" \
        "$desc" "$mod" "$mod" >> "$MOD_BLACKLIST"

    echo "✅  $mod blacklisted"
}

# ───────────────────────────────────────────────
# Profile Application Function
# ───────────────────────────────────────────────
apply_module_blacklist() {
    local profile="$1"
    echo -e "\n🎛️ Applying profile: $profile"

    # Decide which buckets to use for each profile
    local -a buckets=()

    case "$profile" in
        headless_vm)
            echo "Applying 🧰 Headless VM profile (most aggressive)..."
            buckets=(
                "FS_MODULES"
                "NET_MODULES"
                "USB_MODULES"
                "DRM_MODULES"
                "INPUT_MODULES"
                "PLATFORM_MODULES"
                "MISC_MODULES"
            )
            ;;

        physical_server)
            echo "Applying 🖧 Physical Server profile..."
            buckets=(
                "NET_MODULES"
                "DRM_MODULES"
                "INPUT_MODULES"
                "MISC_MODULES"
            )
            ;;

        desktop)
            echo "Applying 🖥️ Desktop profile (least aggressive)..."
            buckets=()
            ;;

        *)
            echo "❌ Unknown profile: '$profile'. No modules will be blacklisted."
            return 1
            ;;
    esac

    # If no buckets are selected for the profile, exit gracefully.
    if [ ${#buckets[@]} -eq 0 ]; then
        echo "✅ Profile '$profile' has no modules to blacklist. Nothing to do."
        return 0
    fi

    # Prepare blacklist file by backing up the old one
    if [[ -f "$MOD_BLACKLIST" ]]; then
        local backup="${MOD_BLACKLIST}.$(date +'%Y%m%d%H%M%S').bak"
        mv "$MOD_BLACKLIST" "$backup"
        echo "Backed up existing blacklist to $backup"
    fi

    # Create a new blacklist file with a header
    {
        echo "# Kernel module blacklist"
        echo "# Profile: $profile"
        echo "# Generated on $(date)"
        echo
    } > "$MOD_BLACKLIST"

    # Process selected buckets and blacklist the modules
    for bucket_name in "${buckets[@]}"; do
        declare -n BUCKET="$bucket_name"
        echo -e "\n🧱 Processing bucket: $bucket_name"
        for mod in "${!BUCKET[@]}"; do
            blacklist_module "$mod" "${BUCKET[$mod]}"
        done
        # Clear the nameref to avoid conflicts
        unset -n BUCKET
    done

    echo -e "\n📄 Final $MOD_BLACKLIST contents:"
    cat "$MOD_BLACKLIST"

    echo -e "\n🔄 Updating initramfs..."
    update-initramfs -u
}

# ───────────────────────────────────────────────
# Verify current module blacklist status
# ───────────────────────────────────────────────
verify_blacklist_status() {
    local file="${1:-$MOD_BLACKLIST}"

    echo -e "\n🔍 Verifying module blacklist status..."
    echo "File: $file"
    echo "---------------------------------------------"

    if [[ ! -f "$file" ]]; then
        echo "❌ Error: Blacklist file not found at $file"
        return 1
    fi

    # Extract module names from 'blacklist <mod>' lines
    local modules
    modules=$(grep -E "^blacklist[[:space:]]+" "$file" | awk '{print $2}')

    if [[ -z "$modules" ]]; then
        echo "No blacklisted modules found in $file"
        return 0
    fi

    # Check each module against currently loaded kernel modules
    while IFS= read -r module; do
        if [[ -z "$module" ]]; then
            continue
        fi

        if lsmod | grep -qw "$module"; then
            echo "⚠️  LOADED   → $module"
        else
            echo "✅ Unloaded → $module"
        fi
    done <<< "$modules"

    echo "---------------------------------------------"
    echo "✅ Verification complete."
}

