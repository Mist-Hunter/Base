#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status.

source $ENV_NETWORK

export FIREHOL_NETSETS_PATH="/etc/firehol/ipsets"
mkdir -p "$FIREHOL_NETSETS_PATH"

echo "export FIREHOL_NETSETS_PATH=\"$FIREHOL_NETSETS_PATH\"" >> $ENV_NETWORK

# ln -sf $SCRIPTS/base/firewall/ipset_firehol.sh /etc/network/if-pre-up.d/lan-nic.d/ipset_firehol.sh

echo "Running FireHOL updater..."
if ! . $SCRIPTS/base/firewall/firehol_updater.sh; then
    echo "Error: FireHOL updater failed"
    exit 1
fi

echo "Creating FireHOL service..."
# Setup Updater
service_name="network-ipset-firehol-updater"

cat <<EOT > /etc/systemd/system/$service_name.service
[Unit]
Description=Network IPset FireHOL Updater

[Service]
Type=simple
ExecStart=/bin/bash $SCRIPTS/base/firewall/firehol_updater.sh
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

echo "Running ipset_firehol.sh..."
systemctl start network-ipset-firehol-updater

# NOTE FireHOL_lvl_1 will take the place of blocking outbound neighbor BOGONS and also blocks outbound to bad reputation in non-bogons.
. $SCRIPTS/base/firewall/remgrep.sh "BOGONS"
iptables -A OUTPUT -m set ! --match-set THE_BAD_IPS dst -p tcp --dport 80 -m comment --comment "apt, firewall, up.sh: Allow HTTP out, except to THE_BAD_IPS. APT Package manager." -j ACCEPT
iptables -A OUTPUT -m set ! --match-set THE_BAD_IPS dst -p tcp --dport 443 -m comment --comment "apt, firewall, up.sh: Allow HTTPS out, except to THE_BAD_IPS_1. APT Package manager." -j ACCEPT
iptables -A OUTPUT -m set ! --match-set THE_BAD_IPS dst -p tcp --dport 21 -m comment --comment "apt, firewall, up.sh: Allow FTP out, except to THE_BAD_IPS. APT Package manager." -j ACCEPT

. $SCRIPTS/base/firewall/save.sh

echo "FireHOL installation complete."