#!/bin/bash
source $ENV_NETWORK

# Debian 11 runs direct from: /etc/network/if-pre-up.d/iptables, Debian 12 via SystemD Service, $INVOCATION_ID or $LISTEN_PID = Run by SystemD
if [ "$IFACE" = "$LAN_NIC" ] || [ -n "$INVOCATION_ID" ] || [ -n "$LISTEN_PID" ]; then
  if [ -n "$INVOCATION_ID" ] || [ -n "$LISTEN_PID" ]; then
    echo "iptables persistence, pre-up, SystemD"
  else
    echo "iptables persistence, pre-up, interface $IFACE"
  fi
 
  # Execute all scripts in the lan-nic.d directory if it exists
  LAN_NIC_DIR="/etc/network/if-pre-up.d/lan-nic.d"  # Removed trailing slash
  if [ -d "$LAN_NIC_DIR" ]; then
    for script in "$LAN_NIC_DIR"/*; do
      if [ -f "$script" ] && [ -x "$script" ]; then
        echo "Running $script"
        "$script"
      fi
    done
  else
    echo "Warning: Directory $LAN_NIC_DIR does not exist"
  fi

  # Default drop prior to rule load incase of error firewall not left open
  iptables -P INPUT DROP
  iptables -P FORWARD DROP
  iptables -P OUTPUT DROP
  iptables -A INPUT -i lo -j ACCEPT
  iptables -A OUTPUT -o lo -j ACCEPT

  # DHCP Check if LAN_NIC contains 'dynamic'
  if ip addr show "$LAN_NIC" | grep -q "dynamic"; then
    echo "The NIC '$LAN_NIC' is dynamic. Applying DHCP rules."
    # Allow DHCP traffic (UDP ports 67 and 68)
    iptables -A INPUT -p udp --sport 67 --dport 68 -m comment --comment "base, firewall, network-pre-up.sh: Allow DHCP client traffic" -j ACCEPT
    iptables -A OUTPUT -p udp --sport 68 --dport 67 -m comment --comment "base, firewall, network-pre-up.sh: Allow DHCP server traffic" -j ACCEPT
  else
    echo "The NIC '$LAN_NIC' is not dynamic. Skipping DHCP rules."
  fi

  # Review $IPTABLES_PERSISTENT_RULES for unset ipsets and create empty ones
  while IFS= read -r line; do
    if echo "$line" | grep -q "match-set"; then
      ipset_name=$(echo "$line" | grep -oP '(?<=match-set )[^ ]+')
      if ! ipset list "$ipset_name" &>/dev/null; then
        echo "Creating empty ipset: $ipset_name"
        ipset create "$ipset_name" hash:ip
      fi
    fi
  done < $IPTABLES_PERSISTENT_RULES

  # Restore iptables rules
  if ! /sbin/iptables-restore < $IPTABLES_PERSISTENT_RULES; then
    echo "Error: Failed to restore iptables rules"
    exit 1
  fi
fi