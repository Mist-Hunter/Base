#!/bin/bash
filter=$1

echo "Apt, firewall, remgrep.sh: Searching '$filter'"
iptables -S | grep $filter

IFS=$'\n'
for rule in `iptables -S| grep $filter | sed -e 's/-A/-D/'`; do
    echo $rule | xargs iptables 
done

echo "Apt, firewall, remgrep.sh: After removal"
iptables -S | grep $filter