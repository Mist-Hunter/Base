#!/bin/bash

# Handles hardware tuning and base security settings.

source /etc/default/grub

apt update

# Build Mirror List
apt install netselect-apt -y
netselect-apt
apt upgrade -y

# Check if the group exists
if getent group "$SECURE_USER_GROUP" >/dev/null; then
  echo "Group $SECURE_USER_GROUP exists."
else
  echo "Group $SECURE_USER_GROUP does not exist."
  
  # Create the group with the specified GID
  if groupadd -g "$SECURE_USER_ID" "$SECURE_USER_GROUP"; then
    echo "Group $SECURE_USER_GROUP created with GID $SECURE_USER_ID."
  else
    echo "Failed to create group $SECURE_USER_GROUP with GID $SECURE_USER_ID."
    exit 1  # Exit with a non-zero status code to indicate an error
  fi
fi

# Check if the user already exists
if id -u "$SECURE_USER" >/dev/null 2>&1; then
  echo "User '$SECURE_USER' already exists."
else
  # Create the user
  useradd -m -s $SHELL -G "$SECURE_USER_GROUP" "$SECURE_USER"

  # Print the user creation details
  echo "User '$SECURE_USER' created successfully."
fi

# Setup Locale 
if ! locale -a 2>/dev/null | grep -qF "en_US"; then
    # MAN: https://www.unix.com/man-page/linux/8/locale-gen/
    echo "Locale '$LANG' is not set."
    apt install locales --no-install-recommends -y # 20.7 MB
    sed -i "s/^# $LANG UTF-8/$LANG UTF-8/" /etc/locale.gen
    locale-gen # Manual > dpkg-reconfigure locales NOTE: local-gen $LANG doesn't work. Only works with sed.
else
    echo "Locale '$LANG' is set."
fi
# Pre-configure localepurge to keep only the desired locale
# https://raw.githubusercontent.com/szepeviktor/debian-server-tools/master/debian-setup/packages/localepurge
apt install localepurge --no-install-recommends -y 
echo "localepurge locales-to-remove string all" | debconf-set-selections
echo "localepurge locales-to-keep string $LANG" | debconf-set-selections
echo "localepurge no-locales boolean false" | debconf-set-selections
dpkg-reconfigure -f noninteractive localepurge
apt remove --purge localepurge -y

# Set Timezone
timedatectl set-timezone $TZ
echo "$TZ" > /etc/timezone
timedatectl

# Permanently record DEV_TYPE
apt install virt-what --no-install-recommends -y # 276 kB # dmidecode adding exim4?
DEV_TYPE=$(virt-what)
if [[ $DEV_TYPE = "" ]]; then
    # If physical, replace with Proc architecture
    DEV_TYPE=$(uname -m)
fi
# Write to /etc/environment
echo "# Device type via 'virt-what'" >> /etc/environment
echo "export DEV_TYPE=$DEV_TYPE" >> /etc/environment
echo ""  >> /etc/environment

# Uninstall virt-what
apt-get remove --purge -y virt-what


if [[ $DEV_TYPE = "kvm" ]]; then
    # Qemu-Guest-Agent
    apt install qemu-guest-agent --no-install-recommends -y # 1128 kB
    #apt remove acpid -y
    
    # Disk Resize
    source $scripts/apt/mount/autoexp.sh
fi

# Remove dhcp6 from dhclient.conf. This doesn't seem to affect ram consumption.
# sed 's/dhcp6\.[a-z-]\+\(, \)\?//g' /etc/dhcp/dhclient.conf

# Add Auto-Resize Terminal & set to Xterm 
tty_dev=$(awk -F': ' '/uart:/ && !/uart:unknown/ {print "ttyS" $1; exit}' /proc/tty/driver/serial) 
apt install xterm --no-install-recommends -y # 12.9 MB
cat <<'EOT' >> ~/.bashrc

# Auto-Resize for Xterm.js / Serial Terminals # https://dannyda.com/2020/06/14/how-to-fix-proxmox-ve-pve-virtual-machine-xterm-js-cant-resize-window-and-no-color/
# If any active terminal is serial, resize
if [[ "$(w)" == *"TTY_DEV"* ]]; then
    trap "resize >/dev/null" DEBUG
    export TERM=xterm-256color
fi
EOT
sed -i "s|TTY_DEV|$tty_dev|g" ~/.bashrc

# Load TCP BBR congestion control module and ensure it loads on boot
modprobe tcp_bbr
echo "tcp_bbr" > /etc/modules-load.d/bbr.conf

# Lynis if not required, consider explicit disabling of core dump in /etc/security/limits.conf file [KRNL-5820] 
cat <<EOT >> /etc/security/limits.conf
* hard core 0
* soft core 0
EOT
cat <<EOT >> /etc/sysctl.d/9999-disable-core-dump.conf
fs.suid_dumpable=0
kernel.core_pattern=|/bin/false
EOT
sysctl -p /etc/sysctl.d/9999-disable-core-dump.conf

cp $SCRIPTS/base/sysctl_vm.conf /etc/sysctl.d/99-virtual-docker-host.conf

# TODO: Check if swap partition / file exists, if not, turn swapiness to 0
# Check if swapon -s has no output
# if ! swapon -s | grep -q .; then
#     # Set vm.swappiness to 0 in /etc/sysctl.d/vm.conf using sed
#     sed -i 's/^vm.swappiness.*/vm.swappiness = 0/' /etc/sysctl.d/vm.conf

#     # Apply the sysctl settings
#     sysctl --system

#     echo "Swappiness set to 0 because no swap is in use."
# else
#     echo "Swap is in use, swappiness remains unchanged."
# fi

sysctl --system

# Lynis Configure password hashing rounds in /etc/login.defs [AUTH-9230] 
#                                   <--- 0 Points
sed -i 's|# SHA_CRYPT_|SHA_CRYPT_|g' /etc/login.defs 

# Lynis Install a PAM module for password strength testing like pam_cracklib or pam_passwdqc [AUTH-9262] #TODO: Neither are present in Debian 12?
apt install libpam-passwdqc --no-install-recommends -y      # <-- 1 point from Lynis, but not relevant to my generated passwords. 

# Lynis Default umask in /etc/login.defs could be more strict like 027 [AUTH-9328] 
sed -i '/UMASK/s/022/027/g' /etc/login.defs

# Lynis Enable auditd to collect audit information [ACCT-9628]
# apt install auditd -y #<-- 2MB of RAM, No points from Lynis

# Lynis, enable DNSSEC
# FIXME: DNSSEC broken with local DNS via SSH ex: delv @local.dnsserver local.domain
# journalctl -u systemd-resolved

#sed -i 's|#DNSSEC=.*|DNSSEC=yes|g' /etc/systemd/resolved.conf
#systemctl restart systemd-resolved.service
#dig google.com +dnssec +short >/dev/null 2>&1 # <--- Seems to wake up resolved so Lynis can see it.

# Lynis consider restricting file permissions [FILE-7524], Double check the permissions of home directories as some might be not strict enough. [HOME-9304]
# No point changes, but whaterver
permPaths=("/boot/grub/grub.cfg" "/etc/crontab")
permissions=600
for pathFile in "${permPaths[@]}"
do
:
    if [ -e "$pathFile" ]; then
        echo "$pathFile"
        chmod $permissions "$pathFile"
        echo "Changed permissions of $pathFile to $permissions"
    else
        echo "$pathFile does not exist"
    fi
done

permPaths=("/etc/cron.d" "/etc/cron.daily" "/etc/cron.hourly" "/etc/cron.weekly" "/etc/cron.monthly")
permissions=700
for pathFile in "${permPaths[@]}"
do
:
    if [ -e "$pathFile" ]; then
        echo "$pathFile"
        chmod $permissions "$pathFile"
        echo "Changed permissions of $pathFile to $permissions"
    else
        echo "$pathFile does not exist"
    fi
done

permPaths=("/home")
permissions=750
for pathFile in "${permPaths[@]}"
do
:
    if [ -e "$pathFile" ]; then
        echo "$pathFile"
        chmod -R $permissions "$pathFile"
        echo "Changed permissions of $pathFile to $permissions"
    else
        echo "$pathFile does not exist"
    fi
done

# Lynis Harden compilers like restricting access to root user only [HRDN-7222]
# No point changes, but whaterver. Removing compilers could break apt, apt-get
# TODO: These changes are getting overwriten?
compilePerm=("as" "cc" "gss" "x86_64-linux-gnu-as" "x86_64-linux-gnu-as")
permissions=700
for compiler in "${compilePerm[@]}"
do
:
    compilePath="/usr/bin/$compiler"
    echo "$compilePath"
    if [ -e "$compilePath" ]; then
        chmod -R $permissions "$compilePath"
        chown root:root $compilePath
        echo "Changed permissions of $compilePath to $permissions, and chowned for root:root"
    else
        echo "$pathFile does not exist"
    fi
done

# TODO: Lynis enable process accounting [ACCT-9622]

# Lynis install package apt-show-versions for patch management purposes [PKGS-7394]
apt install apt-show-versions --no-install-recommends -y        # <--- 1 Point

# Lynis nstall fail2ban to automatically ban hosts that commit multiple authentication errors. [DEB-0880]
# . $SCRIPTS/apt/fail2ban/up.sh                                 # <--- 1 Point, 20 Mb of RAM. Not using SSH. Skipping.

# Lynis harden the system by installing at least one malware scanner, to perform periodic file system scans [HRDN-7230]
apt install rkhunter --no-install-recommends -y                 # <--- 1 Point. Is adding exim4-* via recommends

# Lynis install debsecan to generate lists of vulnerabilities which affect this installation. [DEB-0870]
apt install debsecan --no-install-recommends -y                 # <--- 1 Point. Is adding exim4-* via recommends

# Lynis install apt-listbugs to display a list of critical bugs prior to each APT installation. [DEB-0810]
export APT_LISTBUGS_FRONTEND=none # Allow skipping of bugs during this seesion > https://salsa.debian.org/frx-guest/apt-listbugs/blob/master/FAQ.md#how-can-i-use-apt-listbugs-in-unattended-installationsupgrades
apt install apt-listbugs --no-install-recommends -y             # <--- 1 Point

# Lynis Install debsums for the verification of installed package files against MD5 checksums. [DEB-0875]
apt install debsums --no-install-recommends -y                  # <--- 1 Point

# Lynis Install libpam-tmpdir to set $TMP and $TMPDIR for PAM sessions [DEB-0280]
apt install libpam-tmpdir --no-install-recommends -y            # <--- 1 Point

# Lynis Install needrestart, alternatively to debian-goodies, so that you can run needrestart after upgrades to determine which daemons are using old versions of libraries and need restarting. [DEB-0831]
apt install needrestart --no-install-recommends -y              # <--- 1 Point. O zerpoints > debian-goodies

# Lynis enable logging to an external logging host for archiving purposes and additional protection [LOGG-2154] 
# # <--- 1 Point. Moved to /atp/snmp/up.sh

# Lynis Consider using a tool to automatically apply upgrades [PKGS-7420] 
# apt install unattended-upgrades -y                            # <--- 1 Point <-- Runs all the time eating 20M of ram, already have a solution. Skipping.

# Lynis Enable sysstat to collect accounting (no results) [ACCT-9626], https://www.crybit.com/sysstat-sar-on-ubuntu-debian/
# apt install sysstat -y                                        # No points from Lynis, fulfilled by SNMP anyways (probably)

# Lynis Consider disabling unused kernel modules [FILE-6430] added some modules to the list below.
# Multiple points!

# Lynis set a password on GRUB boot loader to prevent altering boot configuration (e.g. boot in single user mode without password) [BOOT-5122]
# Goal: Password protect editing GRUB, but allow normal booting. https://wiki.archlinux.org/title/GRUB/Tips_and_tricks#Password_protection_of_GRUB_menu
#                                   # <--- 1 Point

# Lynis set a password on GRUB boot loader to prevent altering boot configuration (e.g. boot in single user mode without password) [BOOT-5122]
# Goal: Password protect editing GRUB, but allow normal booting. https://wiki.archlinux.org/title/GRUB/Tips_and_tricks#Password_protection_of_GRUB_menu

# Update GRUB configuration to allow unrestricted booting
sed -i 's|--class os"|--class os --unrestricted"|g' /etc/grub.d/10_linux

# Path to the GRUB custom configuration
grub_cfg="/etc/grub.d/40_custom"

# Generate a random password
new_password=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c 32;)

# Generate the password hash
echo "Generating a GRUB password..."
password_hash=$(echo -e "$new_password\n$new_password" | grub-mkpasswd-pbkdf2 | awk '/grub.pbkdf2.sha512/{print $NF}')

# Create or update the GRUB custom configuration file
cat <<EOT > $grub_cfg
#!/bin/sh
cat <<EOF
if [ "x\${timeout}" != "x-1" ]; then
  if keystatus; then
    if keystatus --shift; then
      set timeout=-1
    else
      set timeout=0
    fi
  else
    if sleep --interruptible \${GRUB_HIDDEN_TIMEOUT} ; then
      set timeout=0
    fi
  fi
fi
set superusers="root"
password_pbkdf2 root $password_hash
EOF
EOT

# Restrict file permissions for security
chmod o-r $grub_cfg

echo "GRUB configuration updated successfully."

# Display the password and wait for user acknowledgment
present_secrets "GRUB Password:$new_password"

# From: lsmod | awk '{print $1}'
# WARNING: This list is very aggressive, removing USB support and many inputs. Only for headless installs. dccp, sctp, rds, tipc, usb-storage, firewire-core, were all recommended off by Lynis.
# TO ChatGPT: Can you create a seperate matching bash array, in the same format that describes what each kernel modules is doing in a single string element. Here's the array: 

# Don't Block 
# "fat", "fat: provides support for the FAT filesystem"
# "vfat", "vfat: provides support for the FAT filesystem" 
# "failover", "failover: provides network failover functionality"
# "net_failover", "net_failover: provides network failover functionality for virtualization"

# List all modules, loaded or not.

#kernel_version=$(uname -r)
#module_path="/lib/modules/${kernel_version}/kernel/drivers"

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
"firewire_core: handles support for FireWire (IEEE 1394) interfaces"
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

### Clean up 
# Remove foregn man pages
rm -rf /usr/share/man/??
rm -rf /usr/share/man/??_*

# Remove Graphics related packages TODO: Most of the packages I'd want to remove are in support of Xterm and Neofetch.
# https://unix.stackexchange.com/questions/424969/how-can-i-remove-all-packages-related-to-gui-in-debian
# dpkg-query -Wf '${Installed-Size}\t${Package}\n' | sort -nr | less

# Triming down before tempalting, only keep the current kernel
. $SCRIPTS/base/debian/kernelPurge.sh

# Clean up un-needed packages (Debian 12). Something above is adding exim4, unsure what.
apt remove -y unattended-upgrades

# Cleanup Services
# Disable SSH if present (debian cloud weird issue)
if systemctl is-enabled ssh.service >/dev/null 2>&1; then
    echo "ssh.service exists and is enabled. Disabling..."
    systemctl disable ssh
else
    echo "ssh.service does not exist or is not enabled."
fi

# sleep="5s"
# echo "systems, debian-base, prepVM.sh: rebooting in $sleep seconds"
# sleep $sleep
# reboot
