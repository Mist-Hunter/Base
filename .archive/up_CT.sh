#!/bin/bash
. ~/.bashrc

# Build Mirror List
#Refference: https://linuxconfig.org/how-to-find-a-fastest-debian-linux-mirror-for-your-etc-apt-sources-list
apt install netselect-apt -y
netselect-apt

# Favorite Apps
apt install -y \
net-tools \
dnsutils \
virt-what \
ncdu

# Make Directories
mkdir -p $base $SCRIPTS $LOGS

cd $SCRIPTS

# Clone Apt
git clone $GIT_APT_URL/Apt.git $SCRIPTS/apt


read -p "systems, debian-base, up.sh: Add Firewall IPtables Rules? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
  . $SCRIPTS/apt/firewall/up.sh
  firewall="yes"
else
  firewall="nofirewall"
fi

# Restic
# . $SCRIPTS/apt/restic/up.sh

# Install under root
. $SCRIPTS/apt/bash-it/up.sh

# Neofetch
. $SCRIPTS/apt/neofetch/up.sh

# DebSec----------------------------------------------------------------------------------------
# User Setup
# https://docs.docker.com/install/linux/linux-postinstall/
# https://manpages.debian.org/jessie/passwd/useradd.8.en.html 
# https://unix.stackexchange.com/questions/419063/how-to-create-user-and-password-in-one-script-for-100-users
# https://www.howtogeek.com/howto/30184/10-ways-to-generate-a-random-password-from-the-command-line/

# SNMP Setup
. $SCRIPTS/apt/snmp/up.sh $firewall

# Turn off IPv6
#. $SCRIPTS/apt/debian/ipv6off.sh

# Set automatic updates
#. $SCRIPTS/apt/autoupdate.sh

# Set NTP Security # Not working in CT?
# ntp.service: Failed to set up mount namespacing: Permission denied
#. $SCRIPTS/apt/ntp/up.sh nofirewall

# Set Postfix server for outbound email alerts
. $SCRIPTS/apt/postfix/up.sh $firewall

# Run Sylog Setup
#. $SCRIPTS/apt/syslog/up.sh

# Run Audit
# . $SCRIPTS/apt/lynis/up.sh


