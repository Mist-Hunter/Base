#!/bin/bash

set -e

ENV_GLOBAL="/root/.config/global.env"
source $ENV_GLOBAL

# NOTE Troubleshoot via logs @ cat /var/log/syslog | grep if-up

echo "Starting ipset manager"

# Import the ipset_process function
source $SCRIPTS/base/firewall/ipset_functions.sh

# Create an array to store all env files
mapfile -t all_env_files < <(
    echo "$ENV_GLOBAL"
    grep -E '^export ENV_[A-Z_]+=".*\.env"' "$ENV_GLOBAL" |
    sed -E 's/^export ENV_[A-Z_]+="(.*\.env)".*/\1/' |
    sort -u  # Remove duplicates
)

echo "Files to be processed:"
printf '%s\n' "${all_env_files[@]}"

for env_file in "${all_env_files[@]}"; do
    if [ -f "$env_file" ]; then
        echo "Processing file: $env_file"
       
        while IFS= read -r line; do
             if [[ $line =~ ^(export[[:space:]]+)?([A-Za-z_]+FQDN)=([^[:space:]]+) ]]; then
                fqdn_var="${BASH_REMATCH[2]}"
                fqdn_value="${BASH_REMATCH[3]}"
                ip_var="${fqdn_var%FQDN}IP"
               
                # Remove any surrounding quotes and leading/trailing whitespace from fqdn_value
                fqdn_value=$(echo "$fqdn_value" | tr -d '"' | tr -d "'" | xargs)
               
                echo "Processing $ip_var from $fqdn_value (found in $env_file)"

                # Single forking statement for all resolution types
                if [[ "$fqdn_value" == *"github"* ]]; then
                    ip_list=$(dig +short _nodes.github.com 2>/dev/null; dig +short github.com 2>/dev/null | sort -u | tr '\n' ' ')
                elif [[ "$fqdn_value" == *"gmail.com"* || "$fqdn_value" == *"google.com"* ]]; then
                    ip_list=$(for domain in "spf.google.com" "_netblocks.google.com" "_netblocks2.google.com" "_netblocks3.google.com"; do 
                        dig +short TXT "$domain" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?'
                    done | sort -u | tr '\n' ' ')
                else
                    ip_list=$(getent ahosts "$fqdn_value" | awk '{print $1}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort -u | tr '\n' ' ')
                fi

                if [ -n "$ip_list" ]; then
                    ipset_process --label "$ip_var" --hash_type "ip" --ip_array $ip_list
                    ip_count=$(echo "$ip_list" | wc -w)
                    echo "Processed $ip_count IP(s) for ipset $ip_var (resolved from $fqdn_value)"
                else
                    echo "Failed to resolve $fqdn_value for $ip_var"
                fi
            fi
        done < "$env_file"
    else
        echo "Warning: File $env_file not found"
    fi
done