#!/bin/bash

source $SCRIPTS/base/firewall/ipset_functions.sh

# Read each nameserver IP from /etc/resolv.conf and add it to the array
while read -r ip; do
    ip_array+=("$ip")
done < <(grep -oP '(?<=^nameserver\s)\S+' /etc/resolv.conf)

ipset_process --label "NAME_SERVERS" --hash_type "ip" --ip_array $ip_array
