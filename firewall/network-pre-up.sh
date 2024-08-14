#!/bin/sh

# Debian 11 runs direct from: /etc/network/if-pre-up.d/iptables, Debian 12 via SystemD Service, $INVOCATION_ID or $LISTEN_PID = Run by SystemD
if [ "$IFACE" = "$LAN_NIC" ] || [ -n "$INVOCATION_ID" ] || [ -n "$LISTEN_PID" ]; then
  if [ -n "$INVOCATION_ID" ] || [ -n "$LISTEN_PID" ]; then
    echo "iptables persistence, pre-up, SystemD"
  else
    echo "iptables persistence, pre-up, interface $IFACE"
  fi
  
  # Execute all scripts in the lan-nic.d directory if it exists
  LAN_NIC_DIR="/etc/network/if-pre-up.d/lan-nic.d/"  # Adjust this path to the correct directory
  if [ -d "$LAN_NIC_DIR" ]; then
    echo "Running scripts in $LAN_NIC_DIR"
    run-parts --verbose "$LAN_NIC_DIR"
  fi

  # Restore iptables rules
  /sbin/iptables-restore < /etc/iptables.up.rules
fi
