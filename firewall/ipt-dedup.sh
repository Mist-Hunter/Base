#!/bin/bash
set -euo pipefail

IPT='iptables -w'
DEBUG=${DEBUG:-0}
DEDUP_ERROR=0

debug() {
    if [[ $DEBUG -eq 1 ]]; then
        echo "DEBUG: $*" >&2
    fi
}

handle_error() {
    local error_message="$1"
    echo "ERROR: $error_message" >&2
    DEDUP_ERROR=1
}

check_docker_user_chain() {
    echo "Checking DOCKER-USER chain:"
    if iptables -L DOCKER-USER -n -v --line-numbers > /dev/null 2>&1; then
        iptables -L DOCKER-USER -n -v --line-numbers
    else
        echo "DOCKER-USER chain does not exist or is empty"
    fi
}

dedup() {
    local table=$1
    echo "Processing table: $table"
   
    if ! iptables -t "$table" -L >/dev/null 2>&1; then
        handle_error "Table $table does not exist or is empty"
        return
    fi
   
    local table_content
    table_content=$(iptables-save | sed -n "/$table/,/COMMIT/p")
    debug "Table content for $table:\n$table_content"
   
    if [[ "$table" == "filter" ]]; then
        check_docker_user_chain
    fi
   
    local duplicates
    duplicates=$(echo "$table_content" | grep '^-' | sort | uniq -dc)
   
    if [[ -n "$duplicates" ]]; then
        echo "Duplicates found in $table table:"
        echo "$duplicates"
       
        while read -r count rule; do
            if [[ $count -gt 1 ]]; then
                local escaped_rule=$(echo "$rule" | sed 's/[]\/$*.^[]/\\&/g')
                debug "Removing duplicate rule: $rule"
                if ! iptables -t "$table" -D $(echo "$rule" | cut -d' ' -f2-); then
                    handle_error "Failed to remove rule: $rule"
                fi
            fi
        done <<< "$duplicates"
    else
        echo "No duplicates found in $table table"
    fi
}

# Main execution
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

if ! iptables-save; then
    handle_error "Failed to save iptables rules"
fi

if [ $DEDUP_ERROR -eq 0 ]; then
    echo "iptables rules have been successfully deduplicated and saved."
else
    echo "iptables deduplication completed with errors."
fi

# Set the exit status of the script
(exit $DEDUP_ERROR)