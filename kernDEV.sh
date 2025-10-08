# ---------------------------------------------
# Detect virtualization context
# ---------------------------------------------
DEV_TYPE=$(systemd-detect-virt || true)
DESKTOP="${DESKTOP:-false}"
MOD_BLACKLIST="/etc/modprobe.d/blacklist.conf"

if ! [[ "$DEV_TYPE" == "$(uname -m)" ]] && ! [[ "$DESKTOP" == "true" ]]; then
    echo "The system was identified as virtualized. DEV_TYPE is: $DEV_TYPE"

    # ---------------------------------------------
    # Define modules to block
    # ---------------------------------------------
    block_modules=(
        ahci
        ata_generic
        ata_piix
        bochs_drm
        cdrom
        cfg80211
        dccp
        drm
        ehci_hcd
        ehci_pci
        evdev
        firewire_core
        firewire-ohci
        floppy
        freevxfs
        hfs
        hfsplus
        iTCO_wdt
        i2c_i801
        i2c_smbus
        jffs2
        joydev
        libata
        pciehp
        pcspkr
        psmouse
        rds
        sctp
        shpchp
        sr_mod
        snd_hda_intel
        squashfs
        tipc
        uhci_hcd
        udf
        usb_common
        usb_storage
        usbcore
    )

    module_description=(
        "ahci: handles AHCI SATA host controller"
        "ata_generic: handles generic ATA host controllers"
        "ata_piix: handles Intel PIIX/ICH ATA host controllers"
        "bochs_drm: provides DRM support for the bochs emulator"
        "cdrom: handles CD-ROM drive support"
        "cfg80211: IEEE 802.11 wireless configuration"
        "dccp: Datagram Congestion Control Protocol"
        "drm: Direct Rendering Manager support"
        "ehci_hcd: EHCI USB host controller"
        "ehci_pci: EHCI USB PCI driver"
        "evdev: Input event support"
        "firewire_core: FireWire core"
        "firewire-ohci: FireWire OHCI driver"
        "floppy: Floppy disk support"
        "freevxfs: FreeVxFS filesystem"
        "hfs: HFS filesystem"
        "hfsplus: HFS+ filesystem"
        "iTCO_wdt: Intel TCO Watchdog"
        "i2c_i801: Intel SMBus controller"
        "i2c_smbus: SMBus over I2C"
        "jffs2: Journalling Flash File System v2"
        "joydev: Joystick support"
        "libata: SCSI to ATA translation layer"
        "pciehp: PCI hotplug"
        "pcspkr: PC speaker"
        "psmouse: PS/2 mouse support"
        "rds: Reliable Datagram Sockets"
        "sctp: Stream Control Transmission Protocol"
        "shpchp: PCI hotplug controller"
        "sr_mod: SCSI CD-ROM support"
        "snd_hda_intel: Intel HDA audio"
        "squashfs: SquashFS filesystem"
        "tipc: Transparent Inter-Process Communication"
        "uhci_hcd: USB 1.1 UHCI"
        "udf: UDF filesystem"
        "usb_common: USB common core"
        "usb_storage: USB mass storage"
        "usbcore: USB core"
    )

    # ---------------------------------------------
    # Rebuild /etc/modprobe.d/blacklist.conf
    # ---------------------------------------------
    if [ -f "$MOD_BLACKLIST" ]; then
        mv "$MOD_BLACKLIST" "${MOD_BLACKLIST}.$(date +'%Y%m%d%H%M%S').bak"
        echo "Moved $MOD_BLACKLIST to backup."
    fi

    {
        echo "# Kernel module blacklist"
        echo "# Generated on $(date)"
        echo "# https://www.kernel.org/doc/Documentation/admin-guide/kernel-parameters.txt"
        echo
    } > "$MOD_BLACKLIST"

    for i in "${!block_modules[@]}"; do
        mod="${block_modules[$i]}"
        desc="${module_description[$i]}"

        # Check if module exists (may not on minimal templates)
        if ! modinfo -n "$mod" >/dev/null 2>&1; then
            echo "$mod not found, skipping."
            continue
        fi

        # Check if built-in
        if modinfo -F builtin "$mod" 2>/dev/null | grep -q '^y$'; then
            echo "$mod is built-in, skipping."
            continue
        fi

        echo "# $desc" >> "$MOD_BLACKLIST"
        echo "blacklist $mod" >> "$MOD_BLACKLIST"
        echo "install $mod /bin/true" >> "$MOD_BLACKLIST"
        echo >> "$MOD_BLACKLIST"
    done

    echo "---------------------------------------------"
    echo "Blacklist file written to $MOD_BLACKLIST"
    echo "---------------------------------------------"

    # ---------------------------------------------
    # Update GRUB kernel cmdline for early blocking
    # ---------------------------------------------
    KVER="$(uname -r)"
    if [ ! -d "/lib/modules/$KVER" ]; then
        echo "⚠️  /lib/modules/$KVER is missing — attempting kernel image reinstall..."
        apt-get update -y
        apt-get install --reinstall -y "linux-image-$KVER" || true
    fi

    BLACKLIST_CMDLINE=$(IFS=, ; echo "${block_modules[*]}")
    GRUB_FILE="/etc/default/grub"

    if ! grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' "$GRUB_FILE"; then
        echo 'GRUB_CMDLINE_LINUX_DEFAULT=""' >> "$GRUB_FILE"
    fi

    if grep -q 'modprobe\.blacklist=' "$GRUB_FILE"; then
        sed -i "s/modprobe\.blacklist=[^\" ]*/modprobe.blacklist=${BLACKLIST_CMDLINE}/" "$GRUB_FILE"
    else
        sed -i "s/^\(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\)\"/\1 modprobe.blacklist=${BLACKLIST_CMDLINE}\"/" "$GRUB_FILE"
    fi

    echo "✅ Updated GRUB_CMDLINE_LINUX_DEFAULT with modprobe.blacklist=${BLACKLIST_CMDLINE}"

    echo "Regenerating GRUB and initramfs..."
    update-grub
    if [ -d "/lib/modules/$KVER" ]; then
        update-initramfs -u
    else
        echo "⚠️  Skipping initramfs update because /lib/modules/$KVER is missing."
    fi

    echo "---------------------------------------------"
    echo "Module blacklisting completed successfully."
    echo "Reboot is required for changes to take effect."
fi

# The path to your blacklist file
BLACKLIST_FILE="/etc/modprobe.d/blacklist.conf"

# Check if the blacklist file exists
if [ ! -f "$BLACKLIST_FILE" ]; then
    echo "Error: Blacklist file not found at $BLACKLIST_FILE"
    exit 1
fi

echo "Checking status of modules in $BLACKLIST_FILE..."
echo "---------------------------------------------"

# Read the file line by line
# We use 'grep' to find lines that start with 'blacklist' and 'awk' to grab the second word (the module name)
grep "^blacklist" "$BLACKLIST_FILE" | awk '{print $2}' | while read -r module; do
    # Check if the module is currently loaded by grepping the output of 'lsmod'
    # The '\b' ensures we match the whole word only (e.g., 'usb' won't match 'usbcore')
    if lsmod | grep -q "\b$module\b"; then
        echo "⚠️  STATUS: LOADED   - $module"
    else
        echo "✅ STATUS: Unloaded - $module"
    fi
done

echo "---------------------------------------------"
echo "Check complete."