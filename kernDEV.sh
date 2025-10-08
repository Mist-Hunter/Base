# ---------------------------------------------
# Detect virtualization context
# ---------------------------------------------
DEV_TYPE=$(systemd-detect-virt || true)
DESKTOP="${DESKTOP:-false}"
MOD_BLACKLIST="/etc/modprobe.d/blacklist.conf"

if ! [[ "$DEV_TYPE" == "$(uname -m)" ]] && ! [[ "$DESKTOP" == "true" ]]; then
    echo "The system was identified as virtualized. DEV_TYPE is: $DEV_TYPE"

    block_modules=(
    "ahci"
    "ata_generic"
    "ata_piix"
    "bochs_drm"
    "cdrom"
    "cfg80211"
    "dccp"
    "drm"
    "ehci"
    "ehci_hcd"
    "ehci_pci"
    "evdev"
    "firewire_core"
    "firewire-ohci"
    "floppy"
    "freevxfs"
    "hcd"
    "hfs"
    "hfsplus"
    "iTCO_wdt"
    "i2c_i801"
    "i2c_smbus"
    "jffs2"
    "joydev"
    "libata"
    "pciehp"
    "pcspkr"
    "psmouse"
    "rds"
    "sctp"
    "shpchp"
    "sr_mod"
    "snd_hda_intel"
    "squashfs"
    "tipc"
    "uhci_hcd"
    "udf"
    "usb_common"
    "usb_storage"
    "usbcore"
    "usd"
    )

    module_description=(
    "ahci: handles AHCI SATA host controller"
    "ata_generic: handles generic ATA host controllers"
    "ata_piix: handles Intel PIIX/ICH ATA host controllers"
    "bochs_drm: provides DRM support for the bochs emulator"
    "cdrom: handles CD-ROM drive support"
    "cfg80211: implements the IEEE 802.11 wireless LAN configuration and management"
    "dccp: implements the Datagram Congestion Control Protocol"
    "drm: provides Direct Rendering Manager support"
    "ehci: handles USB Enhanced Host Controller Interface"
    "ehci_hcd: handles EHCI USB host controller"
    "ehci_pci: handles EHCI USB PCI driver"
    "evdev: handles input event support for devices"
    "firewire_core: handles support for FireWire (IEEE 1394) interfaces [STRG-1846]"
    "firewire-ohci: handles OHCI-1394 host controller driver for FireWire [STRG-1846]"
    "floppy: handles floppy disk drive support"
    "freevxfs: implements the freevxfs filesystem"
    "hcd: handles Host Controller Driver for USB"
    "hfs: implements the HFS filesystem"
    "hfsplus: implements the HFS+ filesystem"
    "iTCO_wdt: handles Intel TCO Watchdog Timer support"
    "i2c_i801: handles Intel SMBus controller driver"
    "i2c_smbus: provides SMBus access through the I2C subsystem"
    "jffs2: implements the Journalling Flash File System version 2"
    "joydev: provides support for Joystick devices"
    "libata: implements the SCSI to ATA Translation Layer"
    "pciehp: handles PCI Hot Plug Controller Driver"
    "pcspkr: handles the PC speaker sound"
    "psmouse: handles PS/2 mouse support"
    "rds: implements the Reliable Datagram Sockets protocol"
    "sctp: implements the Stream Control Transmission Protocol"
    "shpchp: handles PCI Hot Plug Controller Driver"
    "sr_mod: handles SCSI CD-ROM support"
    "snd_hda_intel: implements Intel High Definition Audio codec support"
    "squashfs: implements the SquashFS filesystem"
    "tipc: implements the Transparent Inter-Process Communication protocol"
    "uhci_hcd: handles Universal Host Controller Interface for USB 1.1"
    "udf: implements the Universal Disk Format filesystem"
    "usb_common: handles common functionality for USB drivers"
    "usb_storage: handles USB Mass Storage support"
    "usbcore: handles the core USB functionality"
    "usd: handles support for USB Devices"
    )

    # Empty the blacklist
    if [ -f $MOD_BLACKLIST ]; then
        mv "$MOD_BLACKLIST" "${MOD_BLACKLIST}.$(date +'%Y%m%d%H%M%S').bak" 
        echo "Moved $MOD_BLACKLIST to ${MOD_BLACKLIST}.$(date +'%Y%m%d%H%M%S').bak"
    fi

    touch $MOD_BLACKLIST
    echo "# https://www.kernel.org/doc/Documentation/admin-guide/kernel-parameters.txt , https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/deployment_guide/blacklisting_a_module" >> $MOD_BLACKLIST 
    echo "" >> $MOD_BLACKLIST 

    for i in "${!block_modules[@]}"; do
        echo "beginning module $block_modules[$i]"

        # Check if the module exists
        if ! modinfo -n "${block_modules[$i]}" >/dev/null 2>&1; then
            echo "${block_modules[$i]} module not found, skipping."
            continue
        fi

        # Check if the module is built-in
        if modinfo -F builtin "${block_modules[$i]}" | grep -q "^y$"; then
            echo "${block_modules[$i]} is a built-in module, skipping."
            continue
        fi

        # Check if the module is already blacklisted
        if [ -n "$MOD_BLACKLIST" ] && grep -qw "${block_modules[$i]}" "$MOD_BLACKLIST"; then
            echo "${block_modules[$i]} already in $MOD_BLACKLIST"
        else
            # Remove the module if it is not built-in and not blacklisted
            modprobe -r "${block_modules[$i]}" 2>/dev/null

            # Add the module to the blacklist
            echo "# ${module_description[$i]}" >> "$MOD_BLACKLIST"
            echo "blacklist ${block_modules[$i]}" >> "$MOD_BLACKLIST"
            echo "install ${block_modules[$i]} /bin/true" >> "$MOD_BLACKLIST"
            echo "" >> "$MOD_BLACKLIST"

            echo "${block_modules[$i]} has been blacklisted."
        fi
    done

    echo "$MOD_BLACKLIST contents:"
    cat $MOD_BLACKLIST
    echo "Updating initramfs"
    update-initramfs -u

fi

