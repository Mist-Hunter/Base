#!/bin/bash

echo "Starting NTP Servers"

# Create the ipset if it doesn't already exist
ipset create NTP_SERVERS hash:ip -exist

# Function to add IP addresses to ipset
add_ips_to_ipset() {
    local ip_list=$1
    echo "$ip_list" | while read -r ip; do
        ipset add NTP_SERVERS "$ip" -exist
    done
}

# Function to extract and resolve servers from the config file
extract_and_resolve() {
    local config_file="/etc/systemd/timesyncd.conf"

    # Extract NTP and FallbackNTP servers, handling possible leading whitespace
    local ntp_servers=$(grep -oP '^\s*NTP\s*=\s*\K\S+' "$config_file" | tr ',' '\n')
    local fallback_ntp_servers=$(grep -oP '^\s*FallbackNTP\s*=\s*\K\S+' "$config_file" | tr ',' '\n')

    # Combine server lists and resolve them
    local combined_servers=$(echo "$ntp_servers" "$fallback_ntp_servers")

    # Resolve domain names to IP addresses and add to ipset
    for server in $combined_servers; do
        if [[ "$server" =~ ^[0-9.]+$ ]]; then
            # It's already an IP address
            echo "$server"
        else
            # Resolve domain name to IP addresses
            nslookup "$server" | awk '/^Address: / { print $2 }'
        fi
    done | add_ips_to_ipset
}

# Run the extraction and resolution
extract_and_resolve

