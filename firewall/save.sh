#!/usr/bin/env bash

# Description: This script saves the current iptables rules, deduplicates them, and performs additional checks.
# Usage: ./save.sh
# Dependencies: iptables

set -euo pipefail

# Source global variables
# shellcheck disable=SC1090
source "/root/.config/global.env"

# Initialize error flags
SAVE_ERROR=0
DEDUP_ERROR=0

# Debug flag
DEBUG=${DEBUG:-0}

# Function to log messages
log_message() {
    local message="$1"
    local timestamp
    timestamp=$(date +"%Y-%m-%d @ %H:%M:%S")
    echo -e "# scripts, apt, firewall, save: added by $(whoami) on ${timestamp} - ${message}" | tee -a "${logs}/firewall.log"
}

# Function to handle errors
handle_error() {
    local error_message="$1"
    log_message "ERROR: $error_message"
    SAVE_ERROR=1
}

# Function for debug logging
debug() {
    if [[ $DEBUG -eq 1 ]]; then
        echo "DEBUG: $*" >&2
    fi
}

# Function to check DOCKER-USER chain
check_docker_user_chain() {
    echo "Checking DOCKER-USER chain:"
    if iptables -L DOCKER-USER -n -v --line-numbers > /dev/null 2>&1; then
        iptables -L DOCKER-USER -n -v --line-numbers
    else
        echo "DOCKER-USER chain does not exist or is empty"
    fi
}

# Function to deduplicate iptables rules
dedup() {
    local table=$1
    echo "Processing table: $table"
   
    # Check if the table exists and is not empty
    if ! iptables -t "$table" -L >/dev/null 2>&1; then
        handle_error "Table $table does not exist or is empty"
        return
    fi
   
    # Process the duplicates from the iptables-save output
    iptables-save | awk "/$table/,/COMMIT/ { print }" | grep '^-' | sort | uniq -c | awk '$1 > 1' | while read -r count rule; do
        local remove_count delete_rule
        
        # Calculate how many times to remove the rule (count - 1)
        remove_count=$((count - 1))

        echo "Removing rule: $rule $remove_count times"

        # Remove the rule the appropriate number of times
        for ((i = 0; i < remove_count; i++)); do
            # Replace -A with -D to delete the rule
            delete_rule=$(echo "$rule" | sed 's/^-A /-D /')

            # Run iptables -D to remove the rule
            if ! eval "iptables $delete_rule"; then
                echo "Failed to remove rule: $delete_rule"
            else
                echo "Removed rule: $delete_rule"
            fi
        done
    done
}


# Ensure log directory exists
mkdir -p "$(dirname "${logs}/firewall.log")" || handle_error "Failed to create log directory"

# Log the start of the save operation
log_message "Starting iptables save operation"

# Deduplication process
tables=('filter' 'nat' 'mangle')
failed_tables=()

for table in "${tables[@]}"; do
    if ! dedup "$table"; then
        failed_tables+=("$table")
        handle_error "Error processing table: $table"
    fi
done

if [[ ${#failed_tables[@]} -gt 0 ]]; then
    handle_error "Issues encountered with these tables: ${failed_tables[*]}"
fi

# Save current iptables rules
iptables-save >> "${logs}/firewall.log" || handle_error "Failed to save iptables rules to log"

iptables-save > /etc/iptables.up.rules || handle_error "Failed to save iptables rules to /etc/iptables.up.rules"

# Log the completion of the save operation
if [ $SAVE_ERROR -eq 0 ]; then
    log_message "iptables save operation completed successfully"
else
    log_message "iptables save operation completed with errors"
    # Set the exit status of the script
    exit $SAVE_ERROR
fi

