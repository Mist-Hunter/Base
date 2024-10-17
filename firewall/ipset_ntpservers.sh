#!/bin/bash

# Check if systemd-timesyncd is installed and running
if ! command -v timedatectl &> /dev/null || ! systemctl is-active --quiet systemd-timesyncd; then
    echo "systemd-timesyncd is not installed or not running."
    read -p "Do you want to install and enable it? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        apt update && apt install -y systemd-timesyncd
        systemctl enable --now systemd-timesyncd
    else
        echo "systemd-timesyncd is required for this script. Exiting."
        exit 1
    fi
fi

echo "Starting NTP Servers"
ipset create NTP_SERVERS hash:ip -exist

# Get NTP servers from timedatectl with timeout and error handling
ntp_servers=$(timeout 10s timedatectl show-timesync | grep -E '^(ServerName|FallbackNTPServers)=' | cut -d'=' -f2 | tr '\n' ' ')

if [ $? -eq 124 ]; then
    echo "Error: timedatectl command timed out. Using fallback NTP servers."
    ntp_servers="0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org"
fi

if [ -n "$ntp_servers" ]; then
    echo "NTP Servers: $ntp_servers"
    for server in $ntp_servers; do
        echo "Processing server: $server"
        ips=$(dig +short "$server")
        echo "$server = $ips"
        while IFS= read -r ip; do
            if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                ipset add NTP_SERVERS "$ip" -exist || echo "Failed to add $ip to NTP_SERVERS ipset"
                echo "Added $ip to NTP_SERVERS"
            fi
        done <<< "$ips"
    done
else
    echo "Error: No NTP servers found. Using fallback NTP servers."
    fallback_servers="0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org"
    for server in $fallback_servers; do
        echo "Processing fallback server: $server"
        ips=$(dig +short "$server")
        echo "$server = $ips"
        while IFS= read -r ip; do
            if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                ipset add NTP_SERVERS "$ip" -exist || echo "Failed to add $ip to NTP_SERVERS ipset"
                echo "Added $ip to NTP_SERVERS"
            fi
        done <<< "$ips"
    done
fi

echo "NTP Servers IPSet creation completed"