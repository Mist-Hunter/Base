#!/bin/bash

# systemctl status systemd-timesyncd

# Example:
# FallbackNTP=0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org

# NOTE Don't use log in here! Not sourced

config_file="/etc/systemd/timesyncd.conf"

echo "Starting NTP Servers"
ipset create NTP_SERVERS hash:ip -exist

if [[ -f "$config_file" ]]; then


    ntp_servers=$(grep -oP '^\s*#?\s*NTP\s*=\s*\K.*' "$config_file")
    fallback_ntp_servers=$(grep -oP '^\s*#?\s*FallbackNTP\s*=\s*\K.*' "$config_file")

    combined_servers=$(echo "$ntp_servers" "$fallback_ntp_servers")

    echo "combined_servers=$combined_servers"
    for server in $combined_servers; do
        echo "server=$server"
        ips=$(dig +short "$server")
        echo "$server = $ips"
        while IFS= read -r ip; do
            if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                ipset add NTP_SERVERS "$ip" -exist || error_exit "Failed to create NTP_SERVERS ipset"
                echo "Added $ip to NTP_SERVERS"
            fi
        done <<<"$ips"
    done

else
    echo "Error: Configuration file $config_file does not exist."
fi
