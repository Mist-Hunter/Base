#!/bin/bash

# Ensure a filter argument is provided
if [ $# -ne 1 ]; then
  echo "Usage: $0 <filter>"
  exit 1
fi

filter=$1

# Print the search message
echo "Apt, firewall, remgrep.sh: Searching for '$filter'"

# Search for the filter in iptables rules
iptables_output=$(iptables -S | grep "$filter")

# Check if grep found any results
if [ $? -ne 0 ] || [ -z "$iptables_output" ]; then
  echo "No rules found matching '$filter'. Exiting."
  # exit 1
fi

# Process each rule found by grep
IFS=$'\n'
for rule in $(iptables -S | grep "$filter" | sed -e 's/-A/-D/'); do
    echo "$rule" | xargs iptables
done

# Print the message after removal
echo "Apt, firewall, remgrep.sh: After removal"
iptables -S | grep "$filter"
