#!/bin/bash
source $ENV_SMTP

read -p "apt, updaterservice.sh: Create an APT updater SystemD job? " input 
case $input in
    [yY][eE][sS]|[yY])
echo "Yes"
echo    # (optional) move to a new line

# Check if unattended-upgrades.service is present / enabled 
#TODO: FIXME: Not sure best way to work with Unattended-Upgrades yet. See: /usr/share/unattended-upgrades
if systemctl is-enabled unattended-upgrades.service >/dev/null 2>&1; then
    echo "unattended-upgrades.service exists and is enabled. Disabling..."
    apt remove unattended-upgrades -y # 300mb Disk
    # TODO: Remove unattended-timers
    # systemctl disable unattended-upgrades # 13-20mb RAM
else
    echo "unattended-upgrades.service does not exist or is not enabled."
fi

# Backups -------------------------------------------------------
# Restic backup refference: https://restic.readthedocs.io/en/stable/040_backup.html
# By specifying the option --one-file-system you can instruct restic to only backup files from the file systems the initially specified files or directories reside on. 
read -p "apt, debian, updaterservice.sh: Please enter administrator email [$ADMIN_EMAIL]: " EMAIL
EMAIL=${EMAIL:-$ADMIN_EMAIL}
read -p "apt, debian, updaterservice.sh: Please enter frequency: monthly,weekly,daily,hourly [weekly,wed,midnight]: " freq
freq=${freq:-Wed *-*-* 12:00:00}

# Backup +++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo "apt, debian, updaterservice.sh: Creating SystemD Updater Unit"
SERVICE=apt-updater
cat << EOT > /etc/systemd/system/$SERVICE.service
# Created by $SCRIPTS/docker/incBackSystemD.sh
[Unit]
Description=APT updater services
After=local-fs.target

[Service]
ExecStart=$SCRIPTS/apt/debian/update.sh
Type=oneshot
EOT

cat << EOT > /etc/systemd/system/$SERVICE.timer
# Created by $SCRIPTS/docker/incBackSystemD.sh
[Unit]
Description=APT updater timer

[Timer]
OnCalendar=$freq
Persistent=true

[Install]
WantedBy=timers.target
EOT
systemctl enable $SERVICE.timer
systemctl start $SERVICE.timer

systemctl daemon-reload

 ;;
    [nN][oO]|[nN])
 echo "No"
       ;;
    *)
 echo "Invalid input..."
 exit 1
 ;;
esac