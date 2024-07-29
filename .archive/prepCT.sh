#!/bin/bash

source /etc/default/grub

apt update && apt upgrade -y
apt install virt-what --no-install-recommends -y # 276 kB # dmidecode adding exim4?

# Check if users group exits
if getent group users >/dev/null; then
  echo "Group 'users' exists."
else
  echo "Group 'users' does not exist."
fi

LANG_LOCALE="en_US.UTF-8"
if ! locale -a 2>/dev/null | grep -qF "en_US"; then
    # MAN: https://www.unix.com/man-page/linux/8/locale-gen/
    echo "Locale '$LANG_LOCALE' is not set."
    apt install locales --no-install-recommends -y # 20.7 MB
    sed -i "s/^# $LANG_LOCALE UTF-8/$LANG_LOCALE UTF-8/" /etc/locale.gen
    dpkg-reconfigure locales # NOTE: local-gen $LANG_LOCALE doesn't work. Only works with sed.
    # https://forum.proxmox.com/threads/lxc-perl-warning-setting-locale-failed.32173/post-397146
    sed -i 's|    SendEnv LANG LC_*|#   SendEnv LANG LC_*|g' /etc/ssh/ssh_config
else
    echo "Locale '$LANG_LOCALE' is set."
fi

DEV_TYPE=$(virt-what)
if [[ $DEV_TYPE = "" ]]; then
    # If physical, replace with Proc architecture
    DEV_TYPE=$(uname -m)
fi

bash -c "$(wget -O - $GIT_PROTOCOL://$GIT_SERVER/Zuckuss/Systems/raw/master/debian-base/sysctl_vm.sh)"

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

# Lynis Configure password hashing rounds in /etc/login.defs [AUTH-9230] 
#                                   <--- 0 Points
sed -i 's|# SHA_CRYPT_|SHA_CRYPT_|g' /etc/login.defs 

# Lynis Install a PAM module for password strength testing like pam_cracklib or pam_passwdqc [AUTH-9262] #TODO: Neither are present in Debian 12?
apt install libpam-cracklib --no-install-recommends -y      # <-- 1 point from Lynis, but not relevant to my generated passwords. 

# Lynis Default umask in /etc/login.defs could be more strict like 027 [AUTH-9328] 
sed -i '/UMASK/s/022/027/g' /etc/login.defs

# Lynis Enable auditd to collect audit information [ACCT-9628]
# apt install auditd -y #<-- 2MB of RAM, No points from Lynis

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
sed -i 's|--class os"|--class os --unrestricted"|g' /etc/grub.d/10_linux
GRUB_CFG="/etc/grub.d/40_custom"
password_hash=$(grub-mkpasswd-pbkdf2 | awk '/grub.pbkdf2.sha512/{print $NF}') # <-- TODO: FIXME: Can't see password prompt
# I don't fully understand what is happening, but it seems to be working. This helped the most: https://www.reddit.com/r/debian/comments/ryvdhh/debian_11_grub_password_with_no_password_for/
cat <<EOT > $GRUB_CFG
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
    if sleep --interruptible ${GRUB_HIDDEN_TIMEOUT} ; then
      set timeout=0
    fi
  fi
fi
set superusers="root"
password_pbkdf2 root $password_hash
EOF
EOT
chmod o-r $GRUB_CFG

### Clean up 
# Remove foregn man pages
rm -rf /usr/share/man/??
rm -rf /usr/share/man/??_*

# Remove uneeded Locales # /usr/share/locale
# rm -rd /usr/share/locale
# apt install localepurge -y # https://sleeplessbeastie.eu/2018/09/03/how-to-remove-useless-localizations/

# Remove Graphics related packages TODO: Most of the packages I'd want to remove are in support of Xterm and Neofetch.
# https://unix.stackexchange.com/questions/424969/how-can-i-remove-all-packages-related-to-gui-in-debian
# dpkg-query -Wf '${Installed-Size}\t${Package}\n' | sort -nr | less

# Triming down before tempalting, only keep the current kernel
bash -c "$(wget -O - $GIT_PROTOCOL://$GIT_SERVER/Zuckuss/Apt/raw/branch/master/debian/kernelPurge.sh)"

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

SLEEP="5s"
echo "systems, debian-base, prepVM.sh: rebooting in $SLEEP seconds"
sleep $SLEEP
reboot
