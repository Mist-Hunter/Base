#!/bin/bash

# NOTE having trouble with a variable ENV path be available when this is called.
source "${ENV_GLOBAL:-/root/.config/global.env}"

# Domain Name Servers need to be up before others
. $SCRIPTS/base/firewall/ipset_nameservers.sh

. $SCRIPTS/base/firewall/ipset_gateway.sh

# Execute all scripts in the lan-nic.d directory if it exists
LAN_NIC_DIR="/etc/network/if-up.d/lan-nic.d"  # Adjust this path to the correct directory
for script in "$LAN_NIC_DIR"/*; do
  if [ -f "$script" ] && [ -x "$script" ]; then
    echo "Running $script"
    "$script"
  fi
done
