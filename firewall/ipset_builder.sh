#!/bin/bash

# REV_PROXY_FQDN > DNS Lookup
## LINK Apt\git\up.sh

# SSH_ALLOW > DNS Lookup
## LINK Apt\sshd\up.sh

# SNMP_POLLER > DNS Lookup
## LINK Apt\snmp\up.sh

# SMTP Server
# NOTE SMTP server might be variable DNS @ Google
## LINK Apt\postfix\up.sh

# RESTIC SERVER > DNS Lookup
## LINK Apt\restic\up.sh
## From RESTIC_SERVER_FQDN

# TODO reverse the logic of this script, instead of looping on $ENV_GLOBAL, loop on $IPTABLES_PERSISTENT_RULES looking for ipset names ending in *_IP , and then crawling $ENV_GLOBAL and sourced files for matching *_FQDN variables
# Example: if a vaiable like SNMP_POLLER_IP exsits in $IPTABLES_PERSISTENT_RULES look for SNMP_POLLER_FQDN in $ENV_GLOBAL or sourced file.

# FIXME is this interacting with LAN_GATEWAY?

#!/bin/bash
set -e

echo "Starting ipset manager"

# Import the ipset_process function
source $SCRIPTS/base/firewall/ipset_functions.sh

# Function to find FQDN variable in ENV_GLOBAL and sourced files
find_fqdn_variable() {
    local ip_var_name="$1"
    local fqdn_var_name="${ip_var_name%IP}FQDN"
    local env_global="$ENV_GLOBAL"
    local fqdn_value=""

    # Check ENV_GLOBAL first
    fqdn_value=$(grep "^$fqdn_var_name=" "$env_global" | cut -d'=' -f2)
    if [ -n "$fqdn_value" ]; then
        echo "$fqdn_value" | tr -d '"' | tr -d "'" | xargs
        return
    fi

    # Check exported .env files
    local env_files=$(grep -E '^export ENV_[A-Z_]+=".*\.env"' "$env_global" | sed -E 's/^export ENV_[A-Z_]+="(.*\.env)".*/\1/')
    for env_file in $env_files; do
        fqdn_value=$(grep -E "^export $fqdn_var_name=" "$env_file" | sed -E 's/^export [^=]+="(.*)"/\1/')
        if [ -n "$fqdn_value" ]; then
            echo "$fqdn_value" | tr -d '"' | tr -d "'" | xargs
            return
        fi
    done

    # If we get here, we didn't find the FQDN
    echo ""
}

# Main processing function
process_ipsets() {

    # FIXME this searches active iptables rules, but a catch 22 occurs with initial iptable rule creation that won't create a rule till the ipset exists, but the ipset can't exists till there is a rule.
    # FIXME possible fix to above it to crawl all *_FQDN variable that are sourced in $ENV_GLOBAL, or a sub-sourced file.

    local iptables_rules="$IPTABLES_PERSISTENT_RULES"
    local ipset_names=$(grep -oP 'match-set \K\w+IP' "$iptables_rules" | sort -u)
    for ipset_name in $ipset_names; do
        echo "Processing $ipset_name"
       
        # Check if the ipset exists and is empty
        if ! ipset list "$ipset_name" &>/dev/null || [ "$(ipset list "$ipset_name" | wc -l)" -le 8 ]; then
            fqdn_value=$(find_fqdn_variable "$ipset_name")
            echo "FQDN value found: $fqdn_value"
           
            if [ -n "$fqdn_value" ]; then
                echo "Attempting to resolve: $fqdn_value"
                # Resolve all IPs for the FQDN
                ip_list=$(dig +short "$fqdn_value" | tr '\n' ' ' | sed 's/ $//')
                echo "Resolved IPs: $ip_list"
               
                if [ -n "$ip_list" ]; then
                    ipset_process --label "$ipset_name" --hash_type "ip" --ip_array $ip_list
                    ip_count=$(echo "$ip_list" | wc -w)
                    echo "Added $ip_count IP(s) to ipset $ipset_name (resolved from $fqdn_value)"
                else
                    echo "Failed to resolve $fqdn_value for $ipset_name"
                fi
            else
                echo "No FQDN variable found for $ipset_name"
            fi
        else
            echo "$ipset_name already exists and is not empty. Skipping."
        fi
    done
}

# Function to create ipsets based on FQDN variables
process_all_fqdn_variables() {
    local env_global="$ENV_GLOBAL"

    # Create an array to store all env files
    mapfile -t all_env_files < <(
        echo "$env_global"
        grep -E '^export ENV_[A-Z_]+=".*\.env"' "$env_global" | 
        sed -E 's/^export ENV_[A-Z_]+="(.*\.env)".*/\1/'
    )

    for env_file in "${all_env_files[@]}"; do
        if [ -f "$env_file" ]; then
            echo "Processing file: $env_file"
            while IFS= read -r line; do
                if [[ $line =~ ^([A-Z_]+FQDN)=(.+)$ ]]; then
                    fqdn_var="${BASH_REMATCH[1]}"
                    fqdn_value="${BASH_REMATCH[2]}"
                    ip_var="${fqdn_var%FQDN}IP"
                    
                    # Remove any surrounding quotes from fqdn_value
                    fqdn_value=$(echo "$fqdn_value" | tr -d '"' | tr -d "'")
                    
                    echo "Processing $ip_var from $fqdn_value (found in $env_file)"
                    ip_list=$(dig +short "$fqdn_value" | tr '\n' ' ' | sed 's/ $//')
                    
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
}

# Run the main processing function
process_ipsets