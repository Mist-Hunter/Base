#!/bin/bash

# NOTE having trouble with a variable ENV path be available when this is called.
source "${ENV_GLOBAL:-/root/.config/global.env}"

echo "iptables persistence, pre-up, SystemD. LAN_NIC=$LAN_NIC, SCRIPTS=$SCRIPTS"


# Defaul Drop Rules --------------------------------------------------------------------------------------------------------------------------------
# Default drop prior to rule load incase of error firewall not left open
# FIXME does DOCKER-CHAIN need to be added here?

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP
iptables -I INPUT -i lo -j ACCEPT
iptables -I OUTPUT -o lo -j ACCEPT

# Execute User Scripts -----------------------------------------------------------------------------------------------------------------------------
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

# NOTE Review $IPTABLES_PERSISTENT_RULES for unset ipsets and restore or create empty

# Restore IPSets from files ------------------------------------------------------------------------------------------------------------------------
# Create an associative array to store unique ipset names
declare -A ipset_names

# First loop: Collect unique ipset names
while IFS= read -r line; do
    # Inner loop: Process each ipset name found in the current line
    while read -r ipset_name; do
        if [ -n "$ipset_name" ]; then
            ipset_names["$ipset_name"]=1
            echo "Found ipset: $ipset_name"
        fi
    done < <(echo "$line" | grep -oP '(?<=--match-set )[^ ]+')
done < "$IPTABLES_PERSISTENT_RULES"

echo "Found ${#ipset_names[@]} unique ipset names."

# Second loop: Process each unique ipset
for ipset_name in "${!ipset_names[@]}"; do
    if ! ipset list "$ipset_name" &>/dev/null; then
        netset_file="$NETSET_PATH/${ipset_name,,}.netset"
        if [ -f "$netset_file" ]; then
            echo "Restoring ipset $ipset_name from $netset_file"
            if ipset restore < "$netset_file"; then
                echo "Successfully restored $ipset_name from $netset_file"
            else
                echo "Failed to restore $ipset_name from $netset_file"
            fi
        else
            echo "Creating empty ipset: $ipset_name"
            if ipset create "$ipset_name" hash:ip; then
                echo "Successfully created empty ipset: $ipset_name"
            else
                echo "Failed to create empty ipset: $ipset_name"
            fi
        fi
    else
        echo "Ipset $ipset_name already exists. Skipping."
    fi
done

# Restore iptables rules ---------------------------------------------------------------------------------------------------------------------------
echo "Restoring iptables $IPTABLES_PERSISTENT_RULES"
if ! /sbin/iptables-restore < "$IPTABLES_PERSISTENT_RULES"; then
  echo "Error: Failed to restore iptables rules"
  exit 1
fi
