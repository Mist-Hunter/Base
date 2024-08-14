#!/bin/bash

source $ENV_NETWORK

#The Network
#Best installed first due to later exceptions that refference this package.
#https://github.com/imthenachoman/How-To-Secure-A-Linux-Server/blob/master/README.md#firewall-with-ufw-uncomplicated-firewall

# What is the first adapter after loopback?
# https://stackoverflow.com/questions/19227781/linux-getting-all-network-interface-names
# https://unix.stackexchange.com/questions/29878/can-i-access-nth-line-number-of-standard-output
# https://superuser.com/questions/203272/list-only-the-device-names-of-all-available-network-interfaces
# Return name of second network interface per ip -o link show

echo "[up.sh] script starting."

# Base variables
export IPTABLES_PERSISTENT_RULES="/etc/iptables.up.rules"

cat <<EOT >> $ENV_NETWORK

# Firewall Variables
export LAN_NIC_GATEWAY=""                               # Dynamicaly populated
export IPTABLES_PERSISTENT_RULES="$IPTABLES_PERSISTENT_RULES"
EOT

#Dietpi check ipset / iptables
apt install iptables ipset iprange -y

# Populate ipsets refferenced below
. $SCRIPTS/base/firewall/ipset_BOGONS.sh
. $SCRIPTS/base/firewall/ipset_nameservers.sh

# if [[ $DEV_TYPE = "armv7l" ]] || [[ $DEV_TYPE = "aarch64" ]]; then
#     # TODO: Check if SSHD exists, and add rules. https://linuxhint.com/check-if-ssh-is-running-on-linux/
#     # allow SSH
#     # Reff: https://www.digitalocean.com/community/tutorials/iptables-essentials-common-firewall-rules-and-commands#service-ssh
    
#     iptables -A INPUT -s $GREEN -p tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -m comment --comment "apt, firewall, up.sh: allow SSH connections from GREEN" -j ACCEPT
#     iptables -A OUTPUT -d $GREEN -p tcp --sport 22 -m conntrack --ctstate ESTABLISHED -m comment --comment "apt, firewall, up.sh: allow SSH connections from GREEN" -j ACCEPT
# fi

# Allow ICMP out, but don't reply
iptables -A OUTPUT -p icmp --icmp-type 8 -d 0/0 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT -m comment --comment "apt, firewall, up.sh: Allow ICMP out, but dont reply"

# Allow Loopback
iptables -A INPUT -i lo -m comment --comment "apt, firewall, up.sh: Allow Loopback" -j ACCEPT
iptables -A OUTPUT -o lo -m comment --comment "apt, firewall, up.sh: Allow Loopback" -j ACCEPT

# Allow existing traffic
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -m comment --comment "apt, firewall, up.sh: Allow existing traffic" -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED -m comment --comment "apt, firewall, up.sh: Allow existing traffic" -j ACCEPT

# allow traffic out on port 53 -- DNS, added TCP to support apt-listbugs use of upgraded GLIBC (which needs TCP)
iptables -A OUTPUT -m set --match-set NAME_SERVERS dst -p udp --dport 53 -m comment --comment "apt, firewall, up.sh: Allow DNS via UDP for NAME_SERVERS ipset" -j ACCEPT
iptables -A OUTPUT -m set --match-set NAME_SERVERS dst -p tcp --dport 53 -m comment --comment "apt, firewall, up.sh: Allow DNS via TCP for NAME_SERVERS ipset" -j ACCEPT

# allow traffic out to port 123, NTP. This is in support of systemd-timesyncd which can orginate it's requests on any port. https://serverfault.com/a/1078454
iptables -A OUTPUT -m set ! --match-set BOGONS dst -p udp --dport 123 -j ACCEPT -m comment --comment "apt, firewall, up.sh: allow NTP out"

# allow traffic out for HTTP, HTTPS, or FTP
iptables -I OUTPUT -m set ! --match-set BOGONS dst -p tcp --dport 80 -m comment --comment "apt, firewall, up.sh: Allow HTTP out, except to BOGONS. APT Package manager." -j ACCEPT
iptables -I OUTPUT -m set ! --match-set BOGONS dst -p tcp --dport 443 -m comment --comment "apt, firewall, up.sh: Allow HTTPS out, except to BOGONS. APT Package manager." -j ACCEPT
iptables -I OUTPUT -m set ! --match-set BOGONS dst -p tcp --dport 21 -m comment --comment "apt, firewall, up.sh: Allow FTP out, except to BOGONS. APT Package manager." -j ACCEPT

# allow DHCP
# NOTE handled @ network-pre-up.sh
# iptables -A OUTPUT -p udp --sport 67:68 -m comment --comment "apt, firewall, up.sh: allow DHCP" -j ACCEPT

#Default Blocks
iptables -P OUTPUT DROP
iptables -P INPUT DROP

#Debian Iptables https://wiki.debian.org/iptables
#Persistance
#https://serverfault.com/questions/927673/iptables-restore-sometimes-fails-on-reboot
#https://askubuntu.com/questions/41400/how-do-i-make-the-script-to-run-automatically-when-tun0-interface-up-down-events
#iptables-save > $IPTABLES_PERSISTENT_RULES
. $SCRIPTS/base/firewall/save.sh

# In LXC's for some reason this directory is missing.
if [ ! -d "/etc/network/if-pre-up.d" ]; then
  echo "/etc/network/if-pre-up.d does not exist, creating..."
  mkdir -p "/etc/network/if-pre-up.d"
fi

mkdir -p /etc/network/if-pre-up.d/lan-nic.d/
mkdir -p /etc/network/if-up.d/lan-nic.d/

# Link scripts to run prior to NIC coming up
ln -sf $SCRIPTS/base/firewall/network-pre-up.sh /etc/network/if-pre-up.d/lan-nic
ln -sf $SCRIPTS/base/firewall/ipset_BOGONS.sh /etc/network/if-pre-up.d/lan-nic.d/ipset_BOGONS.sh

# Link scripts to run after NIC comes up
ln -sf $SCRIPTS/base/firewall/network-up.sh /etc/network/if-up.d/lan-nic
ln -sf $SCRIPTS/base/firewall/ipset_builder.sh /etc/network/if-up.d/lan-nic.d/ipset_builder.sh
ln -sf $SCRIPTS/base/firewall/ipset_nameservers.sh /etc/network/if-up.d/lan-nic.d/ipset_nameservers.sh

if grep -q "12" /etc/os-release; then
cat <<EOT > /etc/systemd/system/network-pre-up.service
[Unit]
Description=Network Pre-Up Script

[Service]
Type=oneshot
PassEnvironment=$ENV_NETWORK
ExecStart=$(which bash) -c "/etc/network/if-pre-up.d/lan-nic"

[Install]
WantedBy=network-pre.target
EOT
chown root:root /etc/systemd/system/network-pre-up.service
chmod 644 /etc/systemd/system/network-pre-up.service
systemctl enable network-pre-up.service
systemctl start network-pre-up.service
fi

# Querry Anti-Scan IPtables rules
read -p "Add iptables Anti Port-Scanning? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
  # SNMP Setup
  . $SCRIPTS/base/firewall/anti-scan.sh
fi

# Querry Firehol_level1 Rules
read -p "Add FireHOL Level 1 Subscription? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
  # SNMP Setup
  . $SCRIPTS/base/firewall/firehol_install.sh
fi

echo "[up.sh] script complete."
