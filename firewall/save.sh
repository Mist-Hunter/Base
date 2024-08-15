#!/bin/bash

source $ENV_NETWORK

# Function to move DROP rules to the bottom
move_drops_to_bottom() {
    local temp_file=$(mktemp)
    local drop_rules=$(iptables-save | grep -- "-j DROP")
    iptables-save | grep -v -- "-j DROP" > "$temp_file"
    echo "$drop_rules" >> "$temp_file"
    iptables-restore < "$temp_file"
    rm "$temp_file"
}

# Check if FIREWALL is set to "none"
if [[ "$FIREWALL" == "none" ]]; then
    echo "FIREWALL is set to none. Exiting script."
    exit 0  # Exit with status code 0 as this is an expected condition
fi

# Run the deduplication script
if [ -f "$SCRIPTS/base/firewall/ipt-dedup.sh" ]; then
    . "$SCRIPTS/base/firewall/ipt-dedup.sh"
else
    echo "Warning: Deduplication script not found at $SCRIPTS/base/firewall/ipt-dedup.sh"
fi

# Ensure DROP rules are at the bottom
move_drops_to_bottom

# Create or append to the firewall log
touch "$LOGS/firewall.log"

# Generate a timestamp
timestamp=$(date +"%Y-%m-%d @ %H:%M:%S")

# Save the current iptables rules
echo -e "# scripts, apt, firewall, save to $IPTABLES_PERSISTENT_RULES: added by $(whoami) on $timestamp---------------------------------------" | tee -a "$LOGS/firewall.log"
iptables-save | tee -a "$LOGS/firewall.log" > "$IPTABLES_PERSISTENT_RULES"

echo "Firewall rules have been saved and DROP rules moved to the bottom."