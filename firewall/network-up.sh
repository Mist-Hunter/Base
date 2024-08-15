#!/bin/bash
source $ENV_NETWORK

# NOTE: Removed Debian 11 support, this expect to be run manually via systemD service units

# Idealy gateway is defined first!
export LAN_NIC_GATEWAY=$(ip route show 0.0.0.0/0 dev $LAN_NIC | cut -d\  -f3)
echo "Setting LAN_NIC_GATEWAY: $LAN_NIC_GATEWAY"
sed -i "s/^export LAN_NIC_GATEWAY=.*/export LAN_NIC_GATEWAY=\"$LAN_NIC_GATEWAY\"/" "$ENV_NETWORK"

# Domain Name Servers need to be up before others
. $SCRIPTS/base/firewall/ipset_nameservers.sh

# Execute all scripts in the lan-nic.d directory if it exists
LAN_NIC_DIR="/etc/network/if-up.d/lan-nic.d"  # Adjust this path to the correct directory
for script in "$LAN_NIC_DIR"/*; do
  if [ -f "$script" ] && [ -x "$script" ]; then
    echo "Running $script"
    "$script"
  fi
done