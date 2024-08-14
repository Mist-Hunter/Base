#!/bin/bash
source $ENV_NETWORK

# Debian 11 runs direct from: /etc/network/if-pre-up.d/iptables, Debian 12 via SystemD Service, $INVOCATION_ID or $LISTEN_PID = Run by SystemD
if [ "$IFACE" = "$LAN_NIC" ] || [ -n "$INVOCATION_ID" ] || [ -n "$LISTEN_PID" ]; then

  # Idealy gateway is defined first!
  export LAN_NIC_GATEWAY=$(ip route show 0.0.0.0/0 dev $LAN_NIC | cut -d\  -f3)
  echo "Setting LAN_NIC_GATEWAY: $LAN_NIC_GATEWAY"
  sed -i "s/^LAN_NIC_GATEWAY=.*/LAN_NIC_GATEWAY=\"$LAN_NIC_GATEWAY\"/" "$ENV_NETWORK"
  
  # Execute all scripts in the lan-nic.d directory if it exists
  LAN_NIC_DIR="/etc/network/if-up.d/lan-nic.d/"  # Adjust this path to the correct directory
  for script in "$LAN_NIC_DIR"/*; do
    if [ -f "$script" ] && [ -x "$script" ]; then
      echo "Running $script"
      "$script"
    fi
  done
  
fi