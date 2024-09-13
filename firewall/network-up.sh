#!/bin/bash

# NOTE having trouble with a variable ENV path be available when this is called.
source "${ENV_GLOBAL:-/root/.config/global.env}"

# NOTE: Removed Debian 11 support, this expect to be run manually via systemD service units

# Idealy gateway is defined first!
. $SCRIPTS/base/firewall/set_gateway.sh

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
