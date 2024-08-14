#!/bin/bash

# Debian 11 runs direct from: /etc/network/if-pre-up.d/iptables, Debian 12 via SystemD Service, $INVOCATION_ID or $LISTEN_PID = Run by SystemD
if [ "$IFACE" = "$LAN_NIC" ] || [ -n "$INVOCATION_ID" ] || [ -n "$LISTEN_PID" ]; then
  
  # Execute all scripts in the lan-nic.d directory if it exists
  LAN_NIC_DIR="/etc/network/if-up.d/lan-nic.d/"  # Adjust this path to the correct directory
  for script in "$LAN_NIC_DIR"/*; do
    if [ -f "$script" ] && [ -x "$script" ]; then
      echo "Running $script"
      "$script"
    fi
  done
  
fi