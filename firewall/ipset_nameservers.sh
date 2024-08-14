#!/bin/bash

# Create the ipset if it doesn't already exist
ipset create NAME_SERVERS hash:ip -exist

# Read each nameserver IP from /etc/resolv.conf and add it to the ipset
grep -oP '(?<=^nameserver\s)\S+' /etc/resolv.conf | while read -r ip; do
    ipset add NAME_SERVERS "$ip" -exist
done
