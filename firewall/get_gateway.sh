#!/bin/bash

# TODO this program should run right after gateway becomes accessible (static or lease)
# It's pupose is to write to $ENV_NETWORK and LINK Base\firewall\network-pre-up.sh (which manages ipsets)

# ENV_NETWORK contains only host / domain names
## TODO How does ipset know which variables it should resolve?
## TODO crawl all gobals mentioned in $ENV_GLOBAL looking for _FQDN

# ipset defines actual ips

# GATEWAY_NIC
export LAN_NIC=$(ip -o link show up | awk -F': ' 'NR==2 {print $2; exit}' | sed 's/@.*//')

# TODO write to $ENV_NETWORK


# TODO is it DHCP? 
# ip addr show enp6s18 | grep 'inet '
# If yes, then grab GATEWAY and name servers and overwrite $ENV_NETWORK values

# GATEWAY_IP
export GATEWAY=$(ip route show 0.0.0.0/0 dev $LAN_NIC | cut -d\  -f3)

# DNS
# allow traffic out on port 53 -- DNS, added TCP to support apt-listbugs use of upgraded GLIBC (which needs TCP)
# FIXME change ns to ipset
nameservers=$(grep -oP '(?<=^nameserver\s)\S+' /etc/resolv.conf)
for ns in $nameservers; do
  # Add firewall rules for each 
  iptables -A OUTPUT -d $ns -p udp --dport 53 -m comment --comment "apt, firewall, up.sh: Allow DNS via UDP for $ns" -j ACCEPT
  iptables -A OUTPUT -d $ns -p tcp --dport 53 -m comment --comment "apt, firewall, up.sh: Allow DNS via TCP for $ns" -j ACCEPT
done

## Set DOMAIN from dns
domain=$(grep '^search' /etc/resolv.conf | awk '{print $2}')

## Provided in kick

# REV_PROXY_FQDN > DNS Lookup
## LINK Apt\git\up.sh

# SSH_ALLOW > DNS Lookup
## LINK Apt\sshd\up.sh

# SNMP_POLLER > DNS Lookup
## LINK Apt\snmp\up.sh

# SMTP Server
# NOTE SMTP server might be variable DNS 
## LINK Apt\postfix\up.sh

# RESTIC SERVER > DNS Lookup
## LINK Apt\restic\up.sh
## From RESTIC_SERVER_FQDN

# # From DHCP Lease



