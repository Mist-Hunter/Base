#!/bin/bash

# systemctl status systemd-timesyncd

# Example:
# FallbackNTP=0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org

config_file="/etc/systemd/timesyncd.conf"

if [[ -f "$config_file" ]]; then
    log "Starting NTP Servers"
    ipset create NTP_SERVERS hash:ip -exist

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
                ipset add NTP_SERVERS "$ip" -exist
                log "Added $ip to NTP_SERVERS"
            fi
        done <<<"$ips"
    done

else
    log "Error: Configuration file $config_file does not exist."
fi
