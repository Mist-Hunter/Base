#!/bin/bash

# Ensure a filter argument is provided
if [ $# -ne 1 ]; then
  echo "Usage: $0 <filter>"
  exit 1
fi

filter="$1"

# Print the search message
echo "Apt, firewall, remgrep.sh: Searching for '$filter'"

# Search for the filter in iptables rules
iptables_output=$(sudo iptables -S | grep -F -- "$filter")

# Check if grep found any results
if [ $? -ne 0 ] || [ -z "$iptables_output" ]; then
  echo "No rules found matching '$filter'. Exiting."
  exit 0
fi

# Process each rule found by grep
while IFS= read -r rule; do
    modified_rule=$(echo "$rule" | sed -e 's/^-A/-D/')
    echo "Removing rule: $modified_rule"
    sudo iptables ${modified_rule}
done < <(echo "$iptables_output")

# Print the message after removal
echo "Apt, firewall, remgrep.sh: After removal"
sudo iptables -S | grep -F -- "$filter"