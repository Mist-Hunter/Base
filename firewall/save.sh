#!/usr/bin/env bash

# Description: This script saves the current iptables rules and deduplicates them.
# Usage: ./save.sh
# Dependencies: iptables, ipt-dedup.sh

set -euo pipefail

# Source global variables
# shellcheck disable=SC1090
source "/root/.config/global.env"

# Function to log messages
log_message() {
    local message="$1"
    local timestamp
    timestamp=$(date +"%Y-%m-%d @ %H:%M:%S")
    echo -e "# scripts, apt, firewall, save: added by $(whoami) on ${timestamp} - ${message}" | tee -a "${logs}/firewall.log"
}

# Main execution
main() {
    # Ensure log directory exists
    mkdir -p "$(dirname "${logs}/firewall.log")"

    # Run ipt-dedup in a subshell to avoid variable conflicts
    (
        if [[ -f "${SCRIPTS}/apt/firewall/ipt-dedup.sh" ]]; then
            # shellcheck disable=SC1090
            source "${SCRIPTS}/apt/firewall/ipt-dedup.sh"
        else
            echo "Error: ipt-dedup.sh not found" >&2
            exit 1
        fi
    )

    # Log the start of the save operation
    log_message "Starting iptables save operation"

    # Save current iptables rules
    if ! iptables-save >> "${logs}/firewall.log"; then
        echo "Error: Failed to save iptables rules to log" >&2
        exit 1
    fi

    if ! iptables-save > /etc/iptables.up.rules; then
        echo "Error: Failed to save iptables rules to /etc/iptables.up.rules" >&2
        exit 1
    fi

    log_message "iptables save operation completed successfully"
}

# Run the main function
main