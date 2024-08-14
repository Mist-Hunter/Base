# exit #!/bin/bash
# Example:
# FallbackNTP=0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org

echo "Starting NTP Servers"

# Create the ipset if it doesn't already exist
ipset create NTP_SERVERS hash:ip -exist

# Function to extract and resolve servers from the config file

config_file="/etc/systemd/timesyncd.conf"

# Extract NTP and FallbackNTP servers, handling possible leading whitespace.  | tr ', ' '\n' | grep -v '^#'
ntp_servers=$(grep -oP '^\s*#?\s*NTP\s*=\s*\K.*' "$config_file")
fallback_ntp_servers=$(grep -oP '^\s*#?\s*FallbackNTP\s*=\s*\K.*' "$config_file")

# Combine server lists and resolve them
combined_servers=$(echo "$ntp_servers" "$fallback_ntp_servers")

# Resolve domain names to IP addresses and add to ipset
echo "combined_servers=$combined_servers"
for server in $combined_servers; do

    echo "server=$server"
    nslookup "$server" | awk '/^Address: / { print $2 }'
    ipset add NTP_SERVERS "$ip" -exist

done

