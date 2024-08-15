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

set -e
echo "Starting builder"

# Function to source a file and output variable assignments
source_and_output() {
    local file="$1"
    (
        set -a
        source "$file" >/dev/null 2>&1
        set +a
        compgen -A variable | while read var; do
            echo "$var=${!var}"
        done
    )
}

# Function to create an ipset
create_ipset() {
    local name="$1"
    ipset create "$name" hash:ip -exist
}

# Function to add an IP to an ipset
add_to_ipset() {
    local name="$1"
    local ip="$2"
    ipset add "$name" "$ip" -exist
}

# Function to find FQDN variable in ENV_GLOBAL and sourced files
find_fqdn_variable() {
    local ip_var_name="$1"
    local fqdn_var_name="${ip_var_name%IP}FQDN"
    local env_global="$ENV_GLOBAL"
    local fqdn_value=""

    # Check ENV_GLOBAL first
    fqdn_value=$(grep "^$fqdn_var_name=" "$env_global" | cut -d'=' -f2)
    if [ -n "$fqdn_value" ]; then
        echo "$fqdn_value"
        return
    fi

    # Check exported .env files
    local env_files=$(grep -E '^export ENV_[A-Z_]+=".*\.env"' "$env_global" | sed -E 's/^export ENV_[A-Z_]+="(.*\.env)".*/\1/')
    for env_file in $env_files; do
        echo "Searching $env_file for $fqdn_var_name"
        fqdn_value=$(grep -E "^export $fqdn_var_name=" "$env_file" | sed -E 's/^export [^=]+="(.*)"/\1/')
        if [ -n "$fqdn_value" ]; then
            echo "$fqdn_value"
            return
        fi
    done
}

# Main processing function
process_iptables_rules() {
    local mode="$1"
    local iptables_rules="$IPTABLES_PERSISTENT_RULES"

    # Extract all ipset names ending with IP from iptables rules
    local ipset_names=$(grep -oP 'match-set \K\w+IP' "$iptables_rules" | sort -u)

    for ipset_name in $ipset_names; do
        # Create the ipset
        create_ipset "$ipset_name"

        if [ "$mode" = "up" ]; then
            # Find corresponding FQDN variable
            fqdn_value=$(find_fqdn_variable "$ipset_name")
            
            if [ -n "$fqdn_value" ]; then
                # Resolve the FQDN and add to ipset
                ip=$(dig +short "$fqdn_value" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)
                if [ -n "$ip" ]; then
                    add_to_ipset "$ipset_name" "$ip"
                    echo "Added $ip to ipset $ipset_name"
                else
                    echo "Failed to resolve $fqdn_value for $ipset_name"
                fi
            else
                echo "No FQDN variable found for $ipset_name"
            fi
        fi
    done
}

# Determine the mode based on the directory the script was run from
script_dir=$(dirname "${BASH_SOURCE[0]}")

# Check if the path contains 'if-pre-up.d' or 'if-up.d'
if [[ "$script_dir" == *"if-pre-up.d"* ]]; then
    process_iptables_rules "pre-up"
elif [[ "$script_dir" == *"if-up.d"* ]]; then
    process_iptables_rules "up"
else
    echo "This script should be placed in a directory that contains if-pre-up.d or if-up.d"
    exit 1
fi