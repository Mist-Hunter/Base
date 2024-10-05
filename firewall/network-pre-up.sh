#!/bin/bash

# NOTE having trouble with a variable ENV path be available when this is called.
source "${ENV_GLOBAL:-/root/.config/global.env}"

echo "iptables persistence, pre-up, SystemD. LAN_NIC=$LAN_NIC, SCRIPTS=$SCRIPTS"

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
# FIXME does DOCKER-CHAIN need to be added here?

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP
iptables -I INPUT -i lo -j ACCEPT
iptables -I OUTPUT -o lo -j ACCEPT

echo "Checking for DHCP"

# Check if the network interface is configured for DHCP in /etc/network/interfaces
if grep -q "^iface $LAN_NIC inet dhcp" /etc/network/interfaces; then
  echo "The NIC '$LAN_NIC' is configured for DHCP. Applying DHCP rules."
  # Allow DHCP traffic (UDP ports 67 and 68)
  iptables -I INPUT -p udp --sport 67 --dport 68 -m comment --comment "base, firewall, network-pre-up.sh: Allow DHCP client traffic" -j ACCEPT
  iptables -I OUTPUT -p udp --sport 68 --dport 67 -m comment --comment "base, firewall, network-pre-up.sh: Allow DHCP server traffic" -j ACCEPT
else
  echo "The NIC '$LAN_NIC' is not configured for DHCP. Skipping DHCP rules."
fi

# NOTE Review $IPTABLES_PERSISTENT_RULES for unset ipsets and restore or create empty
echo "Creating empty ipsets in $IPTABLES_PERSISTENT_RULES"
while IFS= read -r line; do
  if echo "$line" | grep -q "match-set"; then
    ipset_name=$(echo "$line" | grep -oP '(?<=match-set )[^ ]+')
    if ! ipset list "$ipset_name" &>/dev/null; then
      netset_file="$NETSET_PATH/${ipset_name,,}.netset"
      if [ -f "$netset_file" ]; then
        echo "Restoring ipset $ipset_name from $netset_file"
        ipset restore < "$netset_file" || echo "Failed to restore $ipset_name from $netset_file"
      else
        echo "Creating empty ipset: $ipset_name"
        ipset create "$ipset_name" hash:ip
      fi
    fi
  fi
done < "$IPTABLES_PERSISTENT_RULES"

# Restore iptables rules
echo "Restoring iptables $IPTABLES_PERSISTENT_RULES"
if ! /sbin/iptables-restore < "$IPTABLES_PERSISTENT_RULES"; then
  echo "Error: Failed to restore iptables rules"
  exit 1
fi
