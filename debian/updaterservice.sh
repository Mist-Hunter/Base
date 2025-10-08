#!/bin/bash
source $ENV_SMTP

read -p "Create APT updater systemd timer? (y/N): " input
[[ "${input,,}" =~ ^y(es)?$ ]] || exit 0

# Remove unattended-upgrades if present (replaced by our timer)
if systemctl is-enabled unattended-upgrades.service &>/dev/null; then
    echo "Removing unattended-upgrades..."
    apt remove -y unattended-upgrades
fi

# Get configuration
read -p "Administrator email [$ADMIN_EMAIL]: " EMAIL
EMAIL=${EMAIL:-$ADMIN_EMAIL}
read -p "Schedule [Wed *-*-* 12:00:00]: " freq
freq=${freq:-Wed *-*-* 12:00:00}

SERVICE=apt-updater

# Create service unit
cat > /etc/systemd/system/$SERVICE.service << EOF
[Unit]
Description=APT package updater
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$SCRIPTS/base/debian/update.sh
# Lynis BOOT-5264: Conservative hardening for timer-triggered service
PrivateTmp=yes
NoNewPrivileges=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes
EOF

# Create timer unit
cat > /etc/systemd/system/$SERVICE.timer << EOF
[Unit]
Description=APT updater timer

[Timer]
OnCalendar=$freq
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now $SERVICE.timer
echo "✓ APT updater timer created: $freq"
systemctl list-timers $SERVICE.timer