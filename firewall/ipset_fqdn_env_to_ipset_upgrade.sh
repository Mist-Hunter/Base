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
                
                # Initialize empty ip_list
                ip_list=""
                
                # Get standard IP resolution first
                standard_ips=$(getent ahosts "$fqdn_value" | awk '{print $1}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort -u)
                
                # Handle GitHub domains
                if [[ "$fqdn_value" =~ github\.com$ ]]; then
                    echo "GitHub domain detected, fetching additional IPs..."
                    # Get GitHub nodes IPs
                    github_nodes=$(dig +short _nodes.github.com | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || true)
                    # Combine and deduplicate IPs
                    ip_list=$(printf "%s\n%s" "$standard_ips" "$github_nodes" | sort -u | tr '\n' ' ')
                
                # Handle Gmail/Google domains
                elif [[ "$fqdn_value" =~ (gmail\.com|google\.com)$ ]]; then
                    echo "Google domain detected, fetching SPF and netblock IPs..."
                    # Temporary file for IP ranges
                    temp_file=$(mktemp)
                    
                    # Fetch SPF and netblock records
                    for spf_domain in "_spf.google.com" "netblocks.google.com" "netblocks2.google.com" "netblocks3.google.com"; do
                        dig +short TXT "$spf_domain" | tr " " "\n" | grep "ip4:" | cut -d":" -f2 >> "$temp_file" || true
                    done
                    
                    # Process IP ranges if any were found
                    if [ -s "$temp_file" ]; then
                        while IFS= read -r range; do
                            google_ips+=" $(getent ahosts $(dig +short $range) | awk '{print $1}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || true)"
                        done < "$temp_file"
                        # Combine all IPs and deduplicate
                        ip_list=$(printf "%s\n%s" "$standard_ips" "$google_ips" | sort -u | tr '\n' ' ')
                        rm -f "$temp_file"
                    else
                        ip_list="$standard_ips"
                    fi
                
                # Handle all other domains
                else
                    ip_list="$standard_ips"
                fi

                if [ -z "$ip_list" ]; then
                    echo "Failed to resolve $fqdn_value for $ip_var"                    
                else
                    ipset_process --label "$ip_var" --hash_type "ip" --ip_array $ip_list
                    ip_count=$(echo "$ip_list" | wc -w)
                    echo "Processed $ip_count IP(s) for ipset $ip_var (resolved from $fqdn_value)"
                fi
            fi
        done < "$env_file"
    else
        echo "Warning: File $env_file not found"
    fi
done