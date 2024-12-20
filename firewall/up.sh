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
export NETSET_PATH="/etc/ipset"

cat <<EOT >> $ENV_NETWORK
# Firewall Variables
export IPTABLES_PERSISTENT_RULES="$IPTABLES_PERSISTENT_RULES"
export NETSET_PATH="$NETSET_PATH"
EOT

#Dietpi check ipset / iptables
apt install iptables ipset iprange -y

# Populate ipsets refferenced below (first-run)
. $SCRIPTS/base/firewall/ipset_nameservers.sh
. $SCRIPTS/base/firewall/ipset_ntpservers.sh
. $SCRIPTS/base/firewall/ipset_gateway.sh
. $SCRIPTS/base/firewall/ipset_fqdn_env_to_ipset.sh
. $SCRIPTS/base/firewall/network-up.sh

# FIXME in OracleCloud, git is comging via SSH which isn' open
# Allow SSH if SSHD is running
# if [[ $DEV_TYPE = "armv7l" ]] || [[ $DEV_TYPE = "aarch64" ]]; then
#     # TODO: Check if SSHD exists, and add rules. https://linuxhint.com/check-if-ssh-is-running-on-linux/
#     # allow SSH
#     # Reff: https://www.digitalocean.com/community/tutorials/iptables-essentials-common-firewall-rules-and-commands#service-ssh
    
#     iptables -I INPUT -s $GREEN -p tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -m comment --comment "apt, firewall, up.sh: allow SSH connections from GREEN" -j ACCEPT
#     iptables -I OUTPUT -d $GREEN -p tcp --sport 22 -m conntrack --ctstate ESTABLISHED -m comment --comment "apt, firewall, up.sh: allow SSH connections from GREEN" -j ACCEPT
# fi

# Allow ICMP out, but don't reply
iptables -I OUTPUT -p icmp --icmp-type 8 -d 0/0 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT -m comment --comment "apt, firewall, up.sh: Allow ICMP out, but dont reply"

# Allow Loopback
iptables -I INPUT -i lo -m comment --comment "apt, firewall, up.sh: Allow Loopback" -j ACCEPT
iptables -I OUTPUT -o lo -m comment --comment "apt, firewall, up.sh: Allow Loopback" -j ACCEPT

# Allow existing traffic
iptables -I INPUT -m conntrack --ctstate ESTABLISHED,RELATED -m comment --comment "apt, firewall, up.sh: Allow existing traffic" -j ACCEPT
iptables -I OUTPUT -m conntrack --ctstate ESTABLISHED -m comment --comment "apt, firewall, up.sh: Allow existing traffic" -j ACCEPT

# allow traffic out on port 53 -- DNS, added TCP to support apt-listbugs use of upgraded GLIBC (which needs TCP)
iptables -I OUTPUT -m set --match-set NAME_SERVERS dst -p udp --dport 53 -m comment --comment "apt, firewall, up.sh: Allow DNS via UDP for NAME_SERVERS ipset" -j ACCEPT
iptables -I OUTPUT -m set --match-set NAME_SERVERS dst -p tcp --dport 53 -m comment --comment "apt, firewall, up.sh: Allow DNS via TCP for NAME_SERVERS ipset" -j ACCEPT

# allow traffic out to port 123, NTP. This is in support of systemd-timesyncd which can orginate it's requests on any port. https://serverfault.com/a/1078454
iptables -I OUTPUT -m set --match-set NTP_SERVERS dst -p udp --dport 123 -j ACCEPT -m comment --comment "Allow NTP traffic to NTP_SERVERS ipset"

# allow traffic out for HTTP, HTTPS, or FTP
read -p "Add FireHOL Level 1 Subscription? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
  . $SCRIPTS/base/firewall/firehol_install.sh
else
  . $SCRIPTS/base/firewall/ipset_BOGONS.sh
  iptables -A OUTPUT -m set ! --match-set BLOCK_LIST dst -p tcp --dport 80 -m comment --comment "apt, firewall, up.sh: Allow HTTP out, except to BLOCK_LIST. APT Package manager." -j ACCEPT
  iptables -A OUTPUT -m set ! --match-set BLOCK_LIST dst -p tcp --dport 443 -m comment --comment "apt, firewall, up.sh: Allow HTTPS out, except to BLOCK_LIST. APT Package manager." -j ACCEPT
  iptables -A OUTPUT -m set ! --match-set BLOCK_LIST dst -p tcp --dport 21 -m comment --comment "apt, firewall, up.sh: Allow FTP out, except to BLOCK_LIST. APT Package manager." -j ACCEPT
fi

# allow DHCP if enabled
dhcp_setting=$( { sed -n "/name: ${LAN_NIC%${LAN_NIC#?}}*/,/^ *$/p" /etc/netplan/90-default.yaml | grep -m1 'dhcp4:' | awk '{print $2}' || echo "false"; } )
if [ "$dhcp_setting" = "true" ]; then
    echo "The NIC '$LAN_NIC' is configured for DHCP. Applying DHCP rules."
    # Allow DHCP traffic (UDP ports 67 and 68)
    iptables -I INPUT -p udp --sport 67 --dport 68 -m comment --comment "base, firewall, network-pre-up.sh: Allow DHCP client traffic" -j ACCEPT
    iptables -I OUTPUT -p udp --sport 68 --dport 67 -m comment --comment "base, firewall, network-pre-up.sh: Allow DHCP server traffic" -j ACCEPT
else
    echo "The NIC '$LAN_NIC' is not configured for DHCP. Skipping DHCP rules."
fi

#Default Blocks
iptables -P OUTPUT DROP
iptables -P INPUT DROP

#Persistance
. $SCRIPTS/base/firewall/save.sh

# In LXC's for some reason this directory is missing.
if [ ! -d "/etc/network/if-pre-up.d" ]; then
  echo "/etc/network/if-pre-up.d does not exist, creating..."
  mkdir -p "/etc/network/if-pre-up.d"
fi

mkdir -p /etc/network/if-pre-up.d/lan-nic.d/
mkdir -p /etc/network/if-up.d/lan-nic.d/
mkdir -p /etc/network/ipset-updates

# Link scripts to run prior to NIC coming up
ln -sf $SCRIPTS/base/firewall/network-pre-up.sh /etc/network/if-pre-up.d/lan-nic

# Link scripts to run after NIC comes up
ln -sf $SCRIPTS/base/firewall/network-up.sh /etc/network/if-up.d/lan-nic
ln -sf $SCRIPTS/base/firewall/ipset_ntpservers.sh /etc/network/if-up.d/lan-nic.d/ipset_ntpservers.sh

# FIXME this doesn't seem to run
ln -sf $SCRIPTS/base/firewall/ipset_fqdn_env_to_ipset.sh /etc/network/if-up.d/lan-nic.d/ipset_fqdn_env_to_ipset.sh

# Link ipset scripts to check for network changes (DNS _fqdn changes) on a schedule
# TODO In addition to running on bootup, the following scripts should run on a nightly schedule
# TODO how would these scripts be handled when just run by bootup? (if rebooted near update time)
# FIXME currently there is no service unit for these, this is prepatory
# NOTE it's possible that this is better handled on reboot only
ln -sf $SCRIPTS/base/firewall/ipset_ntpservers.sh /etc/network/ipset-updates/ipset_ntpservers.sh
ln -sf $SCRIPTS/base/firewall/ipset_fqdn_env_to_ipset.sh /etc/network/ipset-updates/ipset_fqdn_env_to_ipset.sh

# FIXME find some nicer way to source ENV_NETWORK. the && is ugly
# FIXME ifup already runs all scripts in /etc/network/if-pre-up.d, which makes this service only need when ifup is present?
cat <<EOT > /etc/systemd/system/network-pre-up.service
[Unit]
Description=Network Pre-Up Script

[Service]
Type=oneshot
ExecStart=$(which bash) -c "source $ENV_GLOBAL && /etc/network/if-pre-up.d/lan-nic"

[Install]
WantedBy=network-pre.target
EOT
systemctl enable network-pre-up.service

cat <<EOT > /etc/systemd/system/network-up.service
[Unit]
Description=Network Up Script
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=$(which bash) -c "source $ENV_GLOBAL && /etc/network/if-up.d/lan-nic"

[Install]
WantedBy=multi-user.target
EOT

systemctl enable network-up.service

# Querry Anti-Scan IPtables rules
read -p "Add iptables Anti Port-Scanning? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
  # SNMP Setup
  . $SCRIPTS/base/firewall/anti-scan-install.sh
fi

# Start services AFTER options have been selected.
systemctl start network-pre-up.service
systemctl start network-up.service

echo "[up.sh] script complete."
