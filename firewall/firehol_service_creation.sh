#!/bin/bash

service_name="network-ipset-firehol-updater"

cat <<EOT > /etc/systemd/system/$service_name.service
[Unit]
Description=Network IPset FireHOL Updater

[Service]
Type=simple
ExecStart=/bin/bash $scripts/base/firewall/firehol_updater.sh
# Optionally define user/group if needed:
# User=youruser
# Group=yourgroup

[Install]
WantedBy=multi-user.target
EOT

cat <<EOT > /etc/systemd/system/$service_name.timer
[Unit]
Description=Run $service_name daily

[Timer]
OnCalendar=daily
# Optionally adjust when the timer starts:
# OnCalendar=*-*-* 02:00:00
# This would run the script daily at 2 AM

[Install]
WantedBy=timers.target
EOT

systemctl daemon-reload
systemctl enable $service_name.timer
systemctl start $service_name.timer