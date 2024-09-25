#!/usr/bin/env bash

# Description: This script deduplicates iptables rules
# Usage: ./ipt-dedup.sh
# Dependencies: iptables

set -euo pipefail

# Global variables
IPT="iptables -w"

# Function to deduplicate iptables rules for a specific table
dedup() {
    local table="$1"
    
    echo "Processing table: $table"
    
    iptables-save | sed -n "/${table}/,/COMMIT/p" | grep "^-" | sort | uniq -dc | while read -r l
    do
        local c rule
        c=$(echo "$l" | sed "s|^[ ]*\([0-9]*\).*$|\1|")
        rule=$(echo "$l" | sed "s|^[ ]*[0-9]* -A\(.*\)$|-t ${table} -D\1|")
        while [ "${c}" -gt 1 ]; do
            echo "Attempting to remove duplicate rule: iptables $rule"
            if ! eval "${IPT} ${rule}"; then
                echo "Warning: Failed to remove duplicate rule in ${table}" >&2
                echo "Rule: ${rule}" >&2
                # Continue processing other rules instead of returning
                break
            fi
            c=$((c-1))
        done
    done
}

# Main function to deduplicate all tables
main() {
    local tables=("filter" "nat" "mangle")
    local failed_tables=()

    for table in "${tables[@]}"; do
        if ! dedup "$table"; then
            echo "Warning: Issues encountered while deduplicating $table table" >&2
            failed_tables+=("$table")
        fi
    done

    # Save the deduplicated rules
    if ! iptables-save > /etc/iptables.up.rules; then
        echo "Error: Failed to save deduplicated rules" >&2
        return 1
    fi

    if [ ${#failed_tables[@]} -eq 0 ]; then
        echo "iptables rules have been deduplicated and saved successfully"
    else
        echo "iptables rules have been saved, but there were issues with these tables: ${failed_tables[*]}"
        return 1
    fi
}

# Run the main function only if the script is being sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    main
fi