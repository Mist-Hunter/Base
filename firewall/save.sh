#!/usr/bin/env bash

# Description: This script saves the current iptables rules and deduplicates them.
# Usage: ./save.sh
# Dependencies: iptables, ipt-dedup.sh

set -euo pipefail

# Source global variables
# shellcheck disable=SC1090
source "/root/.config/global.env"

# Initialize error flag
SAVE_ERROR=0

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

# Ensure log directory exists
mkdir -p "$(dirname "${logs}/firewall.log")" || handle_error "Failed to create log directory"

# Log the start of the save operation
log_message "Starting iptables save operation"

# Run ipt-dedup
if [[ -f "${SCRIPTS}/apt/firewall/ipt-dedup.sh" ]]; then
    # shellcheck disable=SC1090
    source "${SCRIPTS}/apt/firewall/ipt-dedup.sh" || handle_error "Failed to execute ipt-dedup.sh"
else
    handle_error "ipt-dedup.sh not found"
fi

# Save current iptables rules
iptables-save >> "${logs}/firewall.log" || handle_error "Failed to save iptables rules to log"

iptables-save > /etc/iptables.up.rules || handle_error "Failed to save iptables rules to /etc/iptables.up.rules"

# Log the completion of the save operation
if [ $SAVE_ERROR -eq 0 ]; then
    log_message "iptables save operation completed successfully"
else
    log_message "iptables save operation completed with errors"
fi

# Set the exit status of the script
(exit $SAVE_ERROR)