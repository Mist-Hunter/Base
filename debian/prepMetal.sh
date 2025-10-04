#!/bin/bash

# Handles hardware tuning and base security settings for BARE METAL installations.
# This is a bare metal-safe version that preserves hardware drivers.

# Exit on error
set -e

# Source configuration files
source /etc/default/grub
source /etc/environment

apt update

# Detect if this is bare metal
apt install virt-what --no-install-recommends -y
DEV_TYPE=$(virt-what)
if [[ $DEV_TYPE = "" ]]; then
    # If physical, replace with Proc architecture
    DEV_TYPE=$(uname -m)
    echo "✅ Bare metal detected: $DEV_TYPE"
else
    echo "⚠️  WARNING: This script is for bare metal only!"
    echo "   Detected virtualization: $DEV_TYPE"
    read -p "Continue anyway? (yes/no): " confirm
    if [[ $confirm != "yes" ]]; then
        echo "Exiting."
        exit 1
    fi
fi

# Write to /etc/environment
echo "# Device type via 'virt-what'" >> /etc/environment
echo "export DEV_TYPE=$DEV_TYPE" >> /etc/environment
echo ""  >> /etc/environment

# Uninstall virt-what
apt-get remove --purge -y virt-what

# Build Mirror List
apt install netselect-apt -y
netselect-apt
apt upgrade -y

# Create secure user/group
if getent group "$SECURE_USER_GROUP" >/dev/null; then
  echo "Group $SECURE_USER_GROUP exists."
else
  echo "Group $SECURE_USER_GROUP does not exist."
  
  if groupadd -g "$SECURE_USER_ID" "$SECURE_USER_GROUP"; then
    echo "Group $SECURE_USER_GROUP created with GID $SECURE_USER_ID."
  else
    echo "Failed to create group $SECURE_USER_GROUP with GID $SECURE_USER_ID."
    exit 1
  fi
fi

# Check if the user already exists
if id -u "$SECURE_USER" >/dev/null 2>&1; then
  echo "User '$SECURE_USER' already exists."
else
  useradd -m -s $SHELL -G "$SECURE_USER_GROUP" "$SECURE_USER"
  echo "User '$SECURE_USER' created successfully."
fi

# Add color to LS by uncommenting default bashrc
sed -i '/^# export LS_OPTIONS/s/^# //' ~/.bashrc
sed -i '/^# eval/s/^# //' ~/.bashrc
sed -i '/^# alias ls/s/^# //' ~/.bashrc
sed -i '/^# alias ll/s/^# //' ~/.bashrc
sed -i '/^# alias l/s/^# //' ~/.bashrc
sed -i '/^# alias rm/s/^# //' ~/.bashrc
sed -i '/^# alias cp/s/^# //' ~/.bashrc
sed -i '/^# alias mv/s/^# //' ~/.bashrc

# Setup Locale 
if ! locale -a 2>/dev/null | grep -qF "$LANG"; then
    echo "Locale '$LANG' is not set."
    apt install locales --no-install-recommends -y
    sed -i "s/^# $LANG UTF-8/$LANG UTF-8/" /etc/locale.gen
    locale-gen
else
    echo "Locale '$LANG' is set."
fi

# Purge unnecessary locales
echo "Purging unnecessary locales..."
apt-get install localepurge --no-install-recommends -y
lang_prefix="${LANG%%_*}"
cat <<EOT > /etc/locale.nopurge
MANDELETE
DONTBOTHERNEWLOCALE
SHOWFREEDSPACE
VERBOSE
$lang_prefix
$LANG
EOT
localepurge
apt-get remove --purge -y localepurge
echo "Locale setup and purge completed."

# Set Timezone
timedatectl set-timezone $TZ
echo "$TZ" > /etc/timezone
timedatectl

# Load TCP BBR congestion control module and ensure it loads on boot
modprobe tcp_bbr
echo "tcp_bbr" > /etc/modules-load.d/bbr.conf

# Disable core dumps (Lynis recommendation)
cat <<EOT >> /etc/security/limits.conf
* hard core 0
* soft core 0
EOT
cat <<EOT >> /etc/sysctl.d/9999-disable-core-dump.conf
fs.suid_dumpable=0
kernel.core_pattern=|/bin/false
EOT
sysctl -p /etc/sysctl.d/9999-disable-core-dump.conf

# Apply sysctl settings (if you have a custom config)
if [ -f "$SCRIPTS/base/sysctl_vm.conf" ]; then
    cp $SCRIPTS/base/sysctl_vm.conf /etc/sysctl.d/99-custom.conf
fi

sysctl --system

# Lynis: Configure password hashing rounds in /etc/login.defs
sed -i 's|# SHA_CRYPT_|SHA_CRYPT_|g' /etc/login.defs 

# Lynis: Install a PAM module for password strength testing
apt install libpam-passwdqc --no-install-recommends -y

# Lynis: Default umask in /etc/login.defs could be more strict
sed -i '/UMASK/s/022/027/g' /etc/login.defs

# File permissions hardening
echo "Hardening file permissions..."
permPaths=("/boot/grub/grub.cfg" "/etc/crontab")
permissions=600
for pathFile in "${permPaths[@]}"; do
    if [ -e "$pathFile" ]; then
        chmod $permissions "$pathFile"
        echo "Changed permissions of $pathFile to $permissions"
    fi
done

permPaths=("/etc/cron.d" "/etc/cron.daily" "/etc/cron.hourly" "/etc/cron.weekly" "/etc/cron.monthly")
permissions=700
for pathFile in "${permPaths[@]}"; do
    if [ -e "$pathFile" ]; then
        chmod $permissions "$pathFile"
        echo "Changed permissions of $pathFile to $permissions"
    fi
done

permPaths=("/home")
permissions=750
for pathFile in "${permPaths[@]}"; do
    if [ -e "$pathFile" ]; then
        chmod -R $permissions "$pathFile"
        echo "Changed permissions of $pathFile to $permissions"
    fi
done

# Harden compilers (restrict to root only)
compilePerm=("as" "cc" "gcc" "x86_64-linux-gnu-as" "x86_64-linux-gnu-gcc")
permissions=700
for compiler in "${compilePerm[@]}"; do
    compilePath="/usr/bin/$compiler"
    if [ -e "$compilePath" ]; then
        chmod $permissions "$compilePath"
        chown root:root "$compilePath"
        echo "Changed permissions of $compilePath to $permissions"
    fi
done

# Install security and maintenance packages
echo "Installing security packages..."
apt install apt-show-versions --no-install-recommends -y
apt install rkhunter --no-install-recommends -y
apt install debsecan --no-install-recommends -y
export APT_LISTBUGS_FRONTEND=none
apt install apt-listbugs --no-install-recommends -y
apt install debsums --no-install-recommends -y
apt install libpam-tmpdir --no-install-recommends -y
apt install needrestart --no-install-recommends -y

# GRUB password protection
echo "Setting up GRUB password protection..."
sed -i 's|--class os"|--class os --unrestricted"|g' /etc/grub.d/10_linux

grub_cfg="/etc/grub.d/40_custom"
new_password=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c 32;)
password_hash=$(echo -e "$new_password\n$new_password" | grub-mkpasswd-pbkdf2 | awk '/grub.pbkdf2.sha512/{print $NF}')

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

chmod o-r $grub_cfg
echo "GRUB configuration updated successfully."
echo "⚠️  IMPORTANT: Save this GRUB password: $new_password"

# Kernel module blacklisting - CONSERVATIVE for bare metal
# Only blacklist truly unnecessary protocols and filesystems
echo "Blacklisting unnecessary kernel modules (bare metal safe)..."

MOD_BLACKLIST="/etc/modprobe.d/blacklist-custom.conf"

# BARE METAL SAFE: Only block uncommon protocols and filesystems
# DO NOT block: USB, ATA, SATA, input devices, display drivers, network cards
block_modules=(
    "dccp"          # Uncommon protocol
    "sctp"          # Uncommon protocol
    "rds"           # Uncommon protocol
    "tipc"          # Uncommon protocol
    "freevxfs"      # Uncommon filesystem
    "jffs2"         # Uncommon filesystem (embedded)
    "hfs"           # Mac filesystem
    "hfsplus"       # Mac filesystem
    "udf"           # Uncommon filesystem
    "cramfs"        # Uncommon compressed filesystem
)

module_description=(
    "dccp: Datagram Congestion Control Protocol (rarely used)"
    "sctp: Stream Control Transmission Protocol (rarely used)"
    "rds: Reliable Datagram Sockets protocol (rarely used)"
    "tipc: Transparent Inter-Process Communication (rarely used)"
    "freevxfs: freevxfs filesystem (uncommon)"
    "jffs2: Journalling Flash File System v2 (embedded systems)"
    "hfs: HFS filesystem (Mac)"
    "hfsplus: HFS+ filesystem (Mac)"
    "udf: Universal Disk Format (uncommon)"
    "cramfs: Compressed ROM filesystem (uncommon)"
)

# Backup existing blacklist
if [ -f "$MOD_BLACKLIST" ]; then
    mv "$MOD_BLACKLIST" "${MOD_BLACKLIST}.$(date +'%Y%m%d%H%M%S').bak"
fi

touch "$MOD_BLACKLIST"
echo "# Custom module blacklist for bare metal - conservative approach" >> "$MOD_BLACKLIST"
echo "# Only blocks uncommon protocols and filesystems" >> "$MOD_BLACKLIST"
echo "" >> "$MOD_BLACKLIST"

for i in "${!block_modules[@]}"; do
    # Check if module exists
    if ! modinfo -n "${block_modules[$i]}" >/dev/null 2>&1; then
        echo "${block_modules[$i]} module not found, skipping."
        continue
    fi

    # Check if built-in
    if modinfo -F builtin "${block_modules[$i]}" 2>/dev/null | grep -q "^y$"; then
        echo "${block_modules[$i]} is built-in, skipping."
        continue
    fi

    # Add to blacklist
    echo "# ${module_description[$i]}" >> "$MOD_BLACKLIST"
    echo "blacklist ${block_modules[$i]}" >> "$MOD_BLACKLIST"
    echo "install ${block_modules[$i]} /bin/true" >> "$MOD_BLACKLIST"
    echo "" >> "$MOD_BLACKLIST"
    echo "✅ Blacklisted: ${block_modules[$i]}"
done

echo "Updating initramfs..."
update-initramfs -u

# Cleanup
echo "Cleaning up unnecessary files..."
rm -rf /usr/share/man/??
rm -rf /usr/share/man/??_*

# Clean up packages
apt remove -y unattended-upgrades

# Update GRUB
update-grub

echo ""
echo "=========================================="
echo "✅ Bare metal preparation complete!"
echo "=========================================="
echo ""
echo "⚠️  IMPORTANT: Save your GRUB password!"
echo "Password: $new_password"
echo ""
echo "Consider rebooting to apply all changes."