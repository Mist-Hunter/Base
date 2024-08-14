#!/bin/bash

source $ENV_NETWORK

GATEWAY=$(ip route show 0.0.0.0/0 dev $LAN_NIC | cut -d\  -f3)

# Create the ipset if it doesn't already exist
ipset create GATEWAY hash:ip -exist

ipset add GATEWAY "$GATEWAY" -exist