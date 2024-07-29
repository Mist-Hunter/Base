#!/bin/bash

# Repair DNS Entries
. $SCRIPTS/apt/firewall/remgrep.sh "DNS"
nameservers=$(grep -oP '(?<=^nameserver\s)\S+' /etc/resolv.conf)
for ns in $nameservers; do
  # Add firewall rules for each 
  iptables -A OUTPUT -d $ns -p udp --dport 53 -m comment --comment "apt, firewall, update.sh: Allow DNS via UDP for $ns" -j ACCEPT
  iptables -A OUTPUT -d $ns -p tcp --dport 53 -m comment --comment "apt, firewall, update.sh: Allow DNS via TCP for $ns" -j ACCEPT
done

. $SCRIPTS/apt/firewall/save.sh

# Rerun Net-Select incase of different network Path
#netselect-apt