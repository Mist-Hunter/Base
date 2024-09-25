#!/bin/bash
set -euo pipefail

REMGREP_ERROR=0

log_message() {
    echo "Apt, firewall, remgrep.sh: $1"
}

handle_error() {
    log_message "ERROR: $1"
    REMGREP_ERROR=1
}

process_rules() {
    local filter="$1"
    log_message "Searching for '$filter'"

    local iptables_output
    iptables_output=$(sudo iptables -S | grep -F -- "$filter") || true

    if [ -z "$iptables_output" ]; then
        log_message "No rules found matching '$filter'."
        return
    fi

    while IFS= read -r rule; do
        local modified_rule
        modified_rule=$(echo "$rule" | sed -e 's/^-A/-D/')
        log_message "Removing rule: $modified_rule"
        if ! sudo iptables ${modified_rule}; then
            handle_error "Failed to remove rule: $modified_rule"
        fi
    done < <(echo "$iptables_output")

    log_message "After removal"
    sudo iptables -S | grep -F -- "$filter" || true
}

# Main execution
if [ $# -ne 1 ]; then
    handle_error "Usage: $0 <filter>"
else
    process_rules "$1"
fi

# Set the exit status of the script
(exit $REMGREP_ERROR)