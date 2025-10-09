#!/bin/bash

# Handles hardware tuning and base security settings.

source /etc/default/grub
source /etc/environment

apt update

#'Notice: Some sources can be modernized. Run 'apt modernize-sources' to do so.'
apt modernize-sources -y

# Safety check: abort if major OS upgrade is pending (avoids mid-script reboot)
if command -v do-release-upgrade &>/dev/null; then
    UPGRADE_OUTPUT=$(do-release-upgrade --check-dist-upgrade 2>&1)
    
    if echo "$UPGRADE_OUTPUT" | grep -q "New release"; then
        echo -e "\n🛑 Major OS upgrade available. Proceeding may trigger unexpected reboot."
        echo "$UPGRADE_OUTPUT"
        read -r -p "Continue with minor updates anyway? (y/N): " response
        [[ "${response,,}" =~ ^y(es)?$ ]] || { echo "Aborted."; exit 1; }
    fi
fi

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
    
    # Disk Resize
    # NOTE Resize early to avoid later activites running out of space
    source $SCRIPTS/apt/mount/autoexp.sh
fi

# Build Mirror List
apt install netselect-apt -y
netselect-apt
apt upgrade -y

# Create secure user and group if needed
getent group "$SECURE_USER_GROUP" >/dev/null || \
    groupadd -g "$SECURE_USER_ID" "$SECURE_USER_GROUP" || \
    { echo "Failed to create group $SECURE_USER_GROUP"; exit 1; }

id -u "$SECURE_USER" &>/dev/null || \
    useradd -m -s "$SHELL" -G "$SECURE_USER_GROUP" "$SECURE_USER" && \
    echo "✓ User $SECURE_USER created"

# Remove dhcp6 from dhclient.conf. This doesn't seem to affect ram consumption.
# sed 's/dhcp6\.[a-z-]\+\(, \)\?//g' /etc/dhcp/dhclient.conf

# Enable color ls aliases in bashrc
for pattern in "export LS_OPTIONS" "eval" "alias ls" "alias ll" "alias l" "alias rm" "alias cp" "alias mv"; do
    sed -i "/^# $pattern/s/^# //" ~/.bashrc
done

# Add Auto-Resize Terminal & set to Xterm 
tty_dev=$(awk -F': ' '/uart:/ && !/uart:unknown/ {print "ttyS" $1; exit}' /proc/tty/driver/serial) 
cat <<'EOT' >> ~/.bashrc

# Auto-Resize for Xterm.js / Serial Terminals # https://dannyda.com/2020/06/14/how-to-fix-proxmox-ve-pve-virtual-machine-xterm-js-cant-resize-window-and-no-color/
# If any active terminal is serial, resize
if [[ "$(tty)" == *"TTY_DEV"* ]]; then
    trap "resize >/dev/null" DEBUG
    export TERM=xterm-256color
fi
EOT
sed -i "s|TTY_DEV|$tty_dev|g" ~/.bashrc
export TERM=xterm-256color

# Setup Locale 
if ! locale -a 2>/dev/null | grep -qF "$LANG"; then
    # MAN: https://www.unix.com/man-page/linux/8/locale-gen/
    echo "Locale '$LANG' is not set."
    apt install locales --no-install-recommends -y # 20.7 MB
    sed -i "s/^# $LANG UTF-8/$LANG UTF-8/" /etc/locale.gen
    locale-gen # Manual > dpkg-reconfigure locales NOTE: local-gen $LANG doesn't work. Only works with sed.
else
    echo "Locale '$LANG' is set."
fi

# https://salsa.debian.org/elmig-guest/localepurge
# https://salsa.debian.org/elmig-guest/localepurge/-/raw/master/debian/README.Debian?ref_type=heads
# https://salsa.debian.org/elmig-guest/localepurge/-/blob/master/debian/README.dpkg-path?ref_type=heads
# NOTE Reff: https://packages.debian.org/bookworm/localepurge >> "This tool is a hack which is *not* integrated with the system's package management system and therefore is not for the faint of heart."
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

# Lynis if not required, consider explicit disabling of core dump in /etc/security/limits.conf file [KRNL-5820] 
cat <<EOT >> /etc/security/limits.conf
* hard core 0
* soft core 0
EOT

sysctl --system

# Lynis Install a PAM module for password strength testing like pam_cracklib or pam_passwdqc [AUTH-9262] #TODO: Neither are present in Debian 12?
apt install libpam-passwdqc --no-install-recommends -y      # <-- 1 point from Lynis, but not relevant to my generated passwords. 

# Lynis, enable DNSSEC
# FIXME: DNSSEC broken with local DNS via SSH ex: delv @local.dnsserver local.domain
# journalctl -u systemd-resolved

#sed -i 's|#DNSSEC=.*|DNSSEC=yes|g' /etc/systemd/resolved.conf
#systemctl restart systemd-resolved.service
#dig google.com +dnssec +short >/dev/null 2>&1 # <--- Seems to wake up resolved so Lynis can see it.

# Lynis: restrict file permissions [FILE-7524], harden home directories [HOME-9304]
set_perms() {
    local perms=$1; shift
    local recursive=${1:+"-R "}
    [[ "$1" == "-R" ]] && shift
    for path in "$@"; do
        [[ -e "$path" ]] && chmod $recursive$perms "$path" && echo "✓ $path → $perms" || echo "⊘ $path (not found)"
    done
}
set_perms 600 /boot/grub/grub.cfg /etc/crontab
set_perms 700 /etc/cron.{d,daily,hourly,weekly,monthly}
set_perms 750 -R /home

# Lynis: Harden compilers [HRDN-7222]
# NOTE: Package updates may overwrite these permissions
for compiler in as gcc g++ cc c++ x86_64-linux-gnu-{gcc,g++,as}; do
    [[ -e "/usr/bin/$compiler" ]] && \
        chmod 700 "/usr/bin/$compiler" && \
        chown root:root "/usr/bin/$compiler" && \
        echo "✓ /usr/bin/$compiler → 700" || \
        echo "⊘ /usr/bin/$compiler (not found)"
done

# Lynis BOOT-5264: Harden systemd services
#
# HARD-WON LESSONS - DO NOT REMOVE THESE NOTES:
# ═══════════════════════════════════════════════════════════════
# ❌ ProtectControlGroups=yes
#    → Error: "systemd[2773]: Failed to allocate manager object: Read-only file system"
#    → Cause: Makes /sys/fs/cgroup read-only, breaking systemd's cgroup management
#
# ❌ ProtectKernelTunables=yes
#    → Breaks: ifup@ens18.service, network-ipset-firehol-updater.service
#    → Cause: Makes /proc/sys read-only, preventing network sysctl writes
#
# ❌ ProtectKernelModules=yes
#    → Breaks: Module loading at runtime (may conflict with your module blacklist)
#
# ❌ SystemCallArchitectures=native
#    → Can break: Emulated binaries, some container runtimes
#
# ❌ Hardening dbus, getty, emergency, rescue services
#    → Risk: Can prevent system boot or emergency recovery
# ═══════════════════════════════════════════════════════════════

harden_service() {
    local svc=$1 config=$2
    local override_dir="/etc/systemd/system/${svc}.d"
    
    # Skip if service doesn't exist
    systemctl cat "$svc" &>/dev/null || { echo "⊘ $svc (not installed)"; return; }
    
    mkdir -p "$override_dir"
    echo "$config" > "$override_dir/hardening.conf"
    echo "✓ Hardened $svc"
}

# Conservative hardening - only options proven safe across testing
SAFE='[Service]
PrivateTmp=yes
NoNewPrivileges=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes'

# Only harden simple, stateless services (cron is safest)
for svc in cron; do
    harden_service "${svc}.service" "$SAFE"
done

systemctl daemon-reload
echo "✓ Systemd hardening applied (conservative profile)"

# Lynis enable process accounting for command logging [ACCT-9622]
# Provides forensic tools like 'lastcomm' with negligible resource usage.
# The service enables a kernel feature and does not run as a persistent daemon.
apt install acct --no-install-recommends -y

# Lynis TOOL-5002
# apt install ansible-core --no-install-recommends -y # <---- 0 points?

# Lynis install package apt-show-versions for patch management purposes [PKGS-7394]
apt install apt-show-versions --no-install-recommends -y        # <--- 1 Point

# Lynis Configure minimum and maximum password age in /etc/login.defs [AUTH-9286]
LOGIN_DEFS="/etc/login.defs"
setinconfig -f "${LOGIN_DEFS}" -k PASS_MAX_DAYS -v 90 -d "Maximum days for password use (AUTH-9286)"
setinconfig -f "${LOGIN_DEFS}" -k PASS_MIN_DAYS -v 1
setinconfig -f "${LOGIN_DEFS}" -k PASS_WARN_AGE -v 7

# Lynis Default umask in /etc/login.defs could not be found and defaults usually to 022, which could be more strict like 027 [AUTH-9328]
setinconfig -f "${LOGIN_DEFS}" -k UMASK -v 027 -d "Stricter umask for new files/dirs (AUTH-9328)"

# Lynis Configure password hashing rounds in /etc/login.defs [AUTH-9230]
setinconfig -f "${LOGIN_DEFS}" -k SHA_CRYPT_MIN_ROUNDS -v 5000 -d "Minimum rounds for SHA password hashing (AUTH-9230)"
setinconfig -f "${LOGIN_DEFS}" -k SHA_CRYPT_MAX_ROUNDS -v 10000

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

# Enable daily debsums checking via cron
setinconfig -f /etc/default/debsums -k CRON_CHECK -v daily

# Lynis Install libpam-tmpdir to set $TMP and $TMPDIR for PAM sessions [DEB-0280]
apt install libpam-tmpdir --no-install-recommends -y            # <--- 1 Point

# Lynis Install needrestart, alternatively to debian-goodies, so that you can run needrestart after upgrades to determine which daemons are using old versions of libraries and need restarting. [DEB-0831]
apt install needrestart --no-install-recommends -y              # <--- 1 Point. O zerpoints > debian-goodies

# Configure needrestart to be non-interactive
cat > /etc/needrestart/conf.d/no-prompt.conf << 'EOF'
# Restart services automatically without prompting
$nrconf{restart} = 'a';

# Don't ask about restarting kernel (just notify)
$nrconf{kernelhints} = -1;

# CRITICAL: Never auto-reboot, even if kernel outdated
$nrconf{autoreboot} = 0;
EOF

echo "needrestart configured for automatic, non-interactive mode"

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

# FIXME DEBUG
read -p "SCRIPT PAUSED. prepVM.sh @ 338. Press [Enter] to continue..."

# Kernel Module Blacklisting & Sysctl Settings
source "$SCRIPTS/base/kernel_module_blacklist.sh"
source "$SCRIPTS/base/sysctl_profiles.sh"

read -p "SCRIPT PAUSED. prepVM.sh @ 344. Press [Enter] to continue..."

case "$DEV_TYPE" in
    kvm|vmware|virtualbox|qemu)
        apply_module_blacklist "headless_vm"
        apply_sysctl_profile "virtual-docker-host"
        ;;
    x86_64|amd64)
        apply_module_blacklist "physical_server"
        apply_sysctl_profile "physical-web-server"
        ;;
esac

# FIXME 44 Seconds after Above
read -p "SCRIPT PAUSED. prepVM.sh @ 357. Press [Enter] to continue..."

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

# Auditd Enable auditd to collect audit information [ACCT-9628] 
# FIXME is this breaking and rebooting the system?
# . $SCRIPTS/apt/auditd/up.sh

# Lynis FINT-4350 File Integrity, 2.3 MB of ram
# FIXME still breaking module blacklisting. 
# NOTE May be breaking module blacklist. Moved after. aideinit may need a reboot to kick in update-initramfs -u before moduleblack list
# . $SCRIPTS/apt/aide/up.sh # <---- 0 points?
