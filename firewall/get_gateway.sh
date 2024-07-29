#!/bin/bash

export ETH2=$(ip -o link show up | awk -F': ' 'NR==2 {print $2; exit}')
export ETH2=$(echo $ETH2 | sed 's/@.*//') # Strip @IF## from CT devices. ex eth0@if62 become eth0
export GATEWAY=$(ip route show 0.0.0.0/0 dev $ETH2 | cut -d\  -f3)