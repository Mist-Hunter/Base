#!/bin/bash

set -e

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

# Main processing function
process_env_files() {
    local mode="$1"
    local env_global="$ENV_GLOBAL"

    # Extract all sourced .env files from $ENV_GLOBAL
    local env_files=$(grep -oP "(?<=so
    urce )[^\s]+\.env" "$env_global")

    # Process each .env file
    for env_file in $env_files; do
        # Use the source_and_output function to get all variables
        while IFS='=' read -r var_name var_value; do
            # Check if the variable ends with FQDN
            if [[ $var_name == *FQDN ]]; then
                # Create the corresponding IP variable name
                ip_var_name="${var_name%FQDN}IP"
                
                # Create the ipset
                create_ipset "$ip_var_name"
                
                if [ "$mode" = "up" ]; then
                    # Resolve the FQDN and add to ipset
                    ip=$(dig +short "$var_value" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)
                    if [ -n "$ip" ]; then
                        add_to_ipset "$ip_var_name" "$ip"
                        echo "Added $ip to ipset $ip_var_name"
                    else
                        echo "Failed to resolve $var_value for $ip_var_name"
                    fi
                fi
            fi
        done < <(source_and_output "$env_file")
    done
}

# Determine the mode based on the directory the script was run from
script_dir=${BASH_SOURCE[0]}

# Check if the path contains 'if-pre-up.d' or 'if-up.d'
if [[ "$script_dir" == *"/if-pre-up.d/"* ]]; then
    process_env_files "pre-up"
elif [[ "$script_dir" == *"/if-up.d/"* ]]; then
    process_env_files "up"
else
    echo "$script_dir, This script should be placed in a directory that contains if-pre-up.d or if-up.d"
    exit 1
fi