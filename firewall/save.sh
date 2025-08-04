#!/usr/bin/env bash

# Description: This script saves the current iptables rules, deduplicates them, and performs additional checks.
# Usage: ./save.sh
# Dependencies: iptables, iptables-save, iptables-restore

set -euo pipefail

# Source global variables
# shellcheck disable=SC1090
source "/root/.config/global.env"

# Initialize error flags
SAVE_ERROR=0
DEDUP_ERROR=0

# Debug flag - Set to 1 to enable debug output
DEBUG=${DEBUG:-0}

# Function to log messages
log_message() {
    local message="$1"
    local timestamp
    timestamp=$(date +"%Y-%m-%d @ %H:%M:%S")
    log "# scripts, apt, firewall, save: added by $(whoami) on ${timestamp} - ${message}"
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
    log "Checking DOCKER-USER chain:"
    if iptables -L DOCKER-USER -n -v --line-numbers > /dev/null 2>&1; then
        iptables -L DOCKER-USER -n -v --line-numbers
    else
        log "DOCKER-USER chain does not exist or is empty"
    fi
}

# Improved function to deduplicate iptables rules using iptables-restore
dedup_improved() {
    local table=$1
    log "Processing table: $table for deduplication"
    debug "Starting dedup_improved for table: $table"

    # Check if the table exists and is not empty
    if ! iptables -t "$table" -L >/dev/null 2>&1; then
        handle_error "Table $table does not exist or is empty. Skipping deduplication for this table."
        debug "Table $table does not exist or is empty. Exiting dedup_improved for this table."
        return 0 # Return 0 to indicate it's not a critical failure for this table
    fi

    local temp_rules_file temp_deduped_file
    temp_rules_file=$(mktemp)
    temp_deduped_file=$(mktemp)

    trap "rm -f \"$temp_rules_file\" \"$temp_deduped_file\"; debug \"Cleaned up temp files: $temp_rules_file, $temp_deduped_file\"" EXIT # Ensure cleanup

    debug "Temporary files created: $temp_rules_file, $temp_deduped_file"

    # Dump the current rules for the specific table
    debug "Dumping current rules for table $table to $temp_rules_file"
    if ! iptables-save -t "$table" > "$temp_rules_file"; then
        handle_error "Failed to save rules for table $table."
        debug "Failed to save rules for table $table. Exiting dedup_improved."
        return 1
    fi
    debug "Finished dumping rules for table $table. Size: $(wc -l < "$temp_rules_file") lines."

    # Deduplicate rules by saving to a temporary file, sorting, and using uniq
    # This approach processes the entire table's rules at once
    # Only keep the first occurrence of each rule, effectively deduplicating
    debug "Starting deduplication pipeline (awk | grep | sort -u) for table $table"
    awk "/\*$table/,/COMMIT/ { print }" "$temp_rules_file" | \
    grep -vE '^(#|\*|COMMIT)' | \
    sort -u > "$temp_deduped_file"
    debug "Finished deduplication pipeline for table $table. Output to $temp_deduped_file"

    # Count original and deduplicated rules for logging
    local original_rule_count
    original_rule_count=$(grep '^-A' "$temp_rules_file" | wc -l)
    local deduped_rule_count
    deduped_rule_count=$(grep '^-A' "$temp_deduped_file" | wc -l)
    debug "Original rule count for $table: $original_rule_count"
    debug "Deduped rule count for $table: $deduped_rule_count"

    if [[ $original_rule_count -eq $deduped_rule_count ]]; then
        log "No duplicates found in $table table."
        debug "No duplicates found in $table table. Skipping iptables-restore."
    else
        log "Deduplicated $table table: Removed $((original_rule_count - deduped_rule_count)) duplicate rules."
        
        # Reconstruct the full iptables-restore format for the table
        debug "Reconstructing iptables-restore format for table $table in $temp_rules_file"
        echo "*$table" > "$temp_rules_file" # Overwrite with table header
        cat "$temp_deduped_file" >> "$temp_rules_file" # Append deduped rules
        echo "COMMIT" >> "$temp_rules_file" # Append COMMIT
        debug "Reconstruction complete. New rules file size: $(wc -l < "$temp_rules_file") lines."

        log "Applying deduplicated rules for table $table..."
        # Atomically replace the rules for the table
        local restore_cmd="iptables-restore -t \"$table\" \"$temp_rules_file\""
        debug "Executing command: $restore_cmd"
        if ! eval "$restore_cmd"; then
            handle_error "Failed to apply deduplicated rules for table $table."
            debug "Failed to apply deduplicated rules for table $table. Exiting dedup_improved."
            return 1
        else
            log "Successfully applied deduplicated rules for table $table."
            debug "Successfully applied deduplicated rules for table $table."
        fi
    fi

    debug "Finished dedup_improved for table: $table"
    return 0
}

# Ensure log directory exists
mkdir -p "$(dirname "${logs}/firewall.log")" || handle_error "Failed to create log directory"

# Log the start of the save operation
log_message "Starting iptables save operation"

# Deduplication process
tables=('filter' 'nat' 'mangle')
failed_tables=()

for table in "${tables[@]}"; do
    # Use the improved deduplication function
    if ! dedup_improved "$table"; then
        failed_tables+=("$table")
        handle_error "Error processing table: $table"
    fi
done

if [[ ${#failed_tables[@]} -gt 0 ]]; then
    handle_error "Issues encountered with these tables: ${failed_tables[*]}"
fi

# Save current iptables rules (after deduplication)
# This will now save the *deduplicated* rules
log_message "Saving current iptables rules to ${logs}/firewall.log"
iptables-save >> "${logs}/firewall.log" || handle_error "Failed to save iptables rules to log"

log_message "Saving current iptables rules to /etc/iptables.up.rules"
iptables-save > /etc/iptables.up.rules || handle_error "Failed to save iptables rules to /etc/iptables.up.rules"

# Log the completion of the save operation
if [ $SAVE_ERROR -eq 0 ]; then
    log_message "iptables save operation completed successfully"
else
    log_message "iptables save operation completed with errors"
    # Set the exit status of the script
    exit $SAVE_ERROR
fi
