#!/bin/bash

source $ENV_SMTP
updateLog="$LOGS/apt-debian-update.log"

# Check apt udates --------------------------------------------------------------------------------
apt-get update >/dev/null
update_count=$(apt-get --just-print upgrade | grep -oP '^\d+')
if [ "$update_count" -gt 0 ]; then
    echo "There are updates available."
    date >>$updateLog
    apt-get upgrade -y >>"$updateLog" 2>&1

    if [ -e /var/run/reboot-required ]; then
        sec=5m
        service="aptclean-runonce"
        # Check if the 'mail' command is available
        if command -v mail > /dev/null; then
            mail -s "apt, debian, update.sh: update results from $(hostname), Rebooting in $sec!" $ADMIN_EMAIL <$updateLog
        else
            echo "Warning: 'mail' command not installed. Cannot send email."
        fi
        rm $updateLog
        # SystemD 'oneshot' https://bl.ocks.org/magnetikonline/29263ceed7cd8cee2861b26fb04332da

cat <<EOT >/etc/systemd/system/$service.service
[Unit]
Description=Run $SCRIPTS/apt/clean.sh once after update & reboot, and remove THIS ($service.service) unit.
After=local-fs.target
After=network.target
Wants=neofetch-upgrade-count.service
Before=neofetch-upgrade-count.service

[Service]
# ExecStart=-, the '-' means continue even if a failure occurs.
ExecStart=-$SCRIPTS/apt/clean.sh
ExecStart=-rm /etc/systemd/system/$service.service && systemctl disable $service.service && systemctl daemon-reload
Type=oneshot

[Install]
WantedBy=multi-user.target
EOT

        systemctl enable $service.service
        systemctl daemon-reload

        wall "apt, debian, update.sh: System rebooting in $sec!"
        sleep $sec
        reboot
    else
        mail -s "apt, debian, update.sh: results from $(hostname)" $ADMIN_EMAIL <$updateLog
        echo "apt, debian, update.sh: Reboot not needed, cleaning."
        . $SCRIPTS/apt/clean.sh #TODO get $SCRIPTS variable working in systemd units calling this. See updaterservice.sh
        # systemctl start neofetch-upgrade-count.service
    fi
else
    echo "No updates available."
fi

# TODO: Check SNAP

# TODO: Check Flatpak

# TODO: Update bash-it . $SCRIPTS/apt/bash-it/update.sh

