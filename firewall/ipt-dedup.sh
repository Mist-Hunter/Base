#!/bin/bash

set -euo pipefail

IPT='iptables -w'

# Add debug function
DEBUG=${DEBUG:-0}
debug() {
    if [[ $DEBUG -eq 1 ]]; then
        echo "DEBUG: $*" >&2
    fi
}

dedup() {
    local table=$1
    echo "Processing table: $table"
    
    # Check if the table exists and has content
    if ! iptables -t "$table" -L >/dev/null 2>&1; then
        echo "Warning: Table $table does not exist or is empty" >&2
        return 1
    fi
    
    local table_content
    table_content=$(iptables-save | sed -n "/$table/,/COMMIT/p")
    debug "Table content for $table:\n$table_content"
    
    local duplicates
    duplicates=$(echo "$table_content" | grep '^-' | sort | uniq -dc)
    
    if [[ -n "$duplicates" ]]; then
        echo "Duplicates found in $table table:"
        echo "$duplicates"
        
        # Process duplicates
        while read -r count rule; do
            if [[ $count -gt 1 ]]; then
                local escaped_rule=$(echo "$rule" | sed 's/[]\/$*.^[]/\\&/g')
                debug "Removing duplicate rule: $rule"
                iptables -t "$table" -D $(echo "$rule" | cut -d' ' -f2-) || echo "Failed to remove rule: $rule"
            fi
        done <<< "$duplicates"
    else
        echo "No duplicates found in $table table"
    fi
}

main() {
    local tables=('filter' 'nat' 'mangle')
    local failed_tables=()
    
    for table in "${tables[@]}"; do
        if ! dedup "$table"; then
            failed_tables+=("$table")
            echo "Error processing table: $table" >&2
        fi
    done
    
    if [[ ${#failed_tables[@]} -gt 0 ]]; then
        echo "iptables rules have been saved, but there were issues with these tables: ${failed_tables[*]}" >&2
        return 1
    fi
    
    iptables-save
    echo "iptables rules have been successfully deduplicated and saved."
}

# Run the script
main