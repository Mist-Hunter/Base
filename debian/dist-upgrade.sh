#!/bin/bash
#https://wiki.debian.org/AutomatedUpgrade

export DEBIAN_FRONTEND=noninteractive
export DEBIAN_PRIORITY=critical

# 7/11/2021
# TODO: Is there a way to check for the most recent version of Debian / Ubuntu / Kubuntu?
currentOSVer="Buster"
newOSVer="Bullseye"
cat /etc/os-release

echo "apt, debian, dist-upgrade.sh: Upgrading Debian $currentOSVer to $newOSVer"

# Silly case change
currentOSVer=$(echo "$currentOSVer" | sed -e 's/\(.*\)/\L\1/')
newOSVer=$(echo "$newOSVer" | sed -e 's/\(.*\)/\L\1/')

apt update && apt upgrade -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold'

sed -i "s/$currentOSVer\/updates/$newOSVer-security/g;s/$currentOSVer/$newOSVer/g" /etc/apt/sources.list

apt update
apt full-upgrade -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold'
cat /etc/os-release

# SystemD 'oneshot' https://bl.ocks.org/magnetikonline/29263ceed7cd8cee2861b26fb04332da
servicename="aptclean-runonce"
cat <<EOT > /etc/systemd/system/$servicename.service
[Unit]
Description=Run $SCRIPTS/apt/clean.sh once after upgrade, and remove THIS ($serivcename.service) unit.
After=local-fs.target
After=network.target

[Service]
# ExecStart=-, the '-' means continue even if a failure occurs.
ExecStart=-$SCRIPTS/apt/clean.sh
ExecStart=-rm /etc/systemd/system/$servicename.service && systemctl disable $servicename.service && systemctl daemon-reload
Type=oneshot

[Install]
WantedBy=multi-user.target
EOT
systemctl enable $servicename.service
systemctl daemon-reload
sleep 5s
reboot