#!/bin/bash

source $ENV_NETWORK

export LAN_NIC_GATEWAY=$(ip route show 0.0.0.0/0 dev $LAN_NIC | cut -d\  -f3)
echo "Setting LAN_NIC_GATEWAY: $LAN_NIC_GATEWAY"
sed -i "s/^export LAN_NIC_GATEWAY=.*/export LAN_NIC_GATEWAY=\"$LAN_NIC_GATEWAY\"/" "$ENV_NETWORK"