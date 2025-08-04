#!/usr/bin/env bash

# Description: This script saves the current iptables rules, deduplicates them, and performs additional checks.
# Usage: ./save.sh [--debug | -d]
# Dependencies: iptables, iptables-save, iptables-restore

set -euo pipefail

# Source global variables
# shellcheck disable=SC1090
source "/root/.config/global.env"

# Initialize error flags
SAVE_ERROR=0
DEDUP_ERROR=0

# Debug flag - Default to 0 (off)
DEBUG=0

# Argument Parsing
local_arg_parse_failed=0

for arg in "$@"; do
    case "$arg" in
        --debug|-d)
            DEBUG=1
            ;;
        *)
            echo "Error: Unknown argument '$arg'" >&2
            echo "Usage: $0 [--debug | -d]" >&2
            SAVE_ERROR=1
            local_arg_parse_failed=1
            break
            ;;
    esac
done

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
        return 0
    fi

    local temp_rules_file temp_deduped_file temp_rules_no_comments
    temp_rules_file=$(mktemp)
    temp_deduped_file=$(mktemp)
    temp_rules_no_comments=$(mktemp)

    trap "rm -f \"$temp_rules_file\" \"$temp_deduped_file\" \"$temp_rules_no_comments\"; debug \"Cleaned up temp files: $temp_rules_file, $temp_deduped_file, $temp_rules_no_comments\"" EXIT # Ensure cleanup

    debug "Temporary files created: $temp_rules_file, $temp_deduped_file, $temp_rules_no_comments"

    # Dump the current rules for the specific table
    debug "Dumping current rules for table $table to $temp_rules_file"
    if ! iptables-save -t "$table" > "$temp_rules_file"; then
        handle_error "Failed to save rules for table $table."
        debug "Failed to save rules for table $table. Exiting dedup_improved."
        return 1
    fi
    debug "Finished dumping rules for table $table. Size: $(wc -l < "$temp_rules_file") lines."

    # Deduplicate rules by extracting, stripping comments, sorting, and getting unique rules.
    awk "/\*$table/,/COMMIT/ { print }" "$temp_rules_file" | \
    grep '^-A' | \
    sed -E 's/ -m comment --comment ".*"//' | \
    sort -u > "$temp_deduped_file"

    # Count original and deduplicated rules
    local original_rule_count
    original_rule_count=$(grep '^-A' "$temp_rules_file" | wc -l)
    local deduped_rule_count
    deduped_rule_count=$(wc -l < "$temp_deduped_file")
    debug "Original rule count for $table (including comments): $original_rule_count"
    debug "Deduped rule count for $table (after stripping comments): $deduped_rule_count"

    if [[ $original_rule_count -eq $deduped_rule_count ]]; then
        log "No duplicates found in $table table (ignoring comments)."
        debug "No duplicates found in $table table. Skipping iptables-restore."
    else
        log "Deduplicated $table table: Removed $((original_rule_count - deduped_rule_count)) duplicate rules (ignoring comments)."
        
        # Reconstruct the full iptables-restore format for the table
        debug "Reconstructing iptables-restore format for table $table in $temp_rules_file"
        echo "*$table" > "$temp_rules_file"
        cat "$temp_deduped_file" >> "$temp_rules_file"
        echo "COMMIT" >> "$temp_rules_file"
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

# Main Script Logic guarded by error flag
if [[ $SAVE_ERROR -eq 0 ]]; then
    log_message "Starting iptables save operation"

    # Deduplication process
    tables=('filter' 'nat' 'mangle')
    failed_tables=()

    for table in "${tables[@]}"; do
        if ! dedup_improved "$table"; then
            failed_tables+=("$table")
            handle_error "Error processing table: $table"
        fi
    done

    if [[ ${#failed_tables[@]} -gt 0 ]]; then
        handle_error "Issues encountered with these tables: ${failed_tables[*]}"
    fi

    # Save current iptables rules (after deduplication)
    log_message "Saving current iptables rules to ${logs}/firewall.log"
    iptables-save >> "${logs}/firewall.log" || handle_error "Failed to save iptables rules to log"

    log_message "Saving current iptables rules to /etc/iptables.up.rules"
    iptables-save > /etc/iptables.up.rules || handle_error "Failed to save iptables rules to /etc/iptables.up.rules"
else
    log_message "Skipping iptables save operation due to argument parsing error."
fi

# Log the completion of the save operation
if [ $SAVE_ERROR -eq 0 ]; then
    log_message "iptables save operation completed successfully"
else
    log_message "iptables save operation completed with errors"
    true
fi
