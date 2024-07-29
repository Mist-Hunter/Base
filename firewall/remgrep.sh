#!/bin/bash
FILTER=$1

echo "Apt, firewall, remgrep.sh: Searching $FILTER:"
iptables -S | grep $FILTER

IFS=$'\n'
for rule in `iptables -S| grep $FILTER | sed -e 's/-A/-D/'`; do
    echo $rule | xargs iptables 
done

echo "Apt, firewall, remgrep.sh: After removal"
iptables -S | grep $FILTER