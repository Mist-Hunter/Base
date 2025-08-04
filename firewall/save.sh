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
for arg in "$@"; do
    case "$arg" in
        --debug|-d)
            DEBUG=1
            ;;
        *)
            echo "Error: Unknown argument '$arg'" >&2
            echo "Usage: $0 [--debug | -d]" >&2
            SAVE_ERROR=1
            break
            ;;
    esac
done

# Function to log messages
log_message() {
    local message="$1"
    local timestamp
    timestamp=$(date +"%Y-%m-%d @ %H:%M:%S")
    # Assuming 'log' is an alias or function; if not, replace with `echo`
    echo "# scripts, apt, firewall, save: added by $(whoami) on ${timestamp} - ${message}"
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

# Function to deduplicate iptables rules
dedup_improved() {
    local table=$1
    log_message "Processing table: $table for deduplication"
    debug "Starting dedup_improved for table: $table"

    local temp_rules_file temp_restore_file
    temp_rules_file=$(mktemp)
    temp_restore_file=$(mktemp)
    
    # Ensure temporary files are removed on exit
    trap 'rm -f "$temp_rules_file" "$temp_restore_file"' EXIT HUP INT QUIT TERM

    # Dump the current rules for the specific table
    if ! iptables-save -t "$table" > "$temp_rules_file"; then
        handle_error "Failed to save rules for table $table."
        return 1
    fi

    # Check if there are any append rules (-A) to process
    if ! grep -q '^-A' "$temp_rules_file"; then
        log_message "No append rules (-A) to process in table '$table'. Skipping."
        return 0
    fi
    
    # Separate append rules from everything else (chain defs, other rules, etc.)
    local non_append_lines
    non_append_lines=$(grep -v '^-A' "$temp_rules_file")
    local append_rules
    append_rules=$(grep '^-A' "$temp_rules_file")

    local original_rule_count
    original_rule_count=$(echo "$append_rules" | wc -l)
    
    # Deduplicate append rules (exact duplicates, including comments)
    local deduped_append_rules
    deduped_append_rules=$(echo "$append_rules" | sort -u)

    local deduped_rule_count
    deduped_rule_count=$(echo "$deduped_append_rules" | wc -l)

    debug "Original -A rule count for $table: $original_rule_count"
    debug "Deduplicated -A rule count for $table: $deduped_rule_count"

    if [[ $original_rule_count -eq $deduped_rule_count ]]; then
        log_message "No duplicate -A rules found in $table table."
    else
        log_message "Deduplicated $table table: Removed $((original_rule_count - deduped_rule_count)) duplicate -A rules."
        
        # Reconstruct the full iptables-restore format file
        debug "Reconstructing iptables-restore format for table $table in $temp_restore_file"
        {
            # Write all original lines that weren't -A rules, excluding the final COMMIT
            echo "$non_append_lines" | grep -v '^COMMIT'
            # Write the unique -A rules
            echo "$deduped_append_rules"
            # Write the final COMMIT
            echo "COMMIT"
        } > "$temp_restore_file"
        
        log_message "Applying deduplicated rules for table $table..."
        debug "Executing command: iptables-restore --table=\"$table\" < \"$temp_restore_file\""

        # Atomically replace the rules for the table using the corrected command
        if ! iptables-restore --table="$table" < "$temp_restore_file"; then
            handle_error "Failed to apply deduplicated rules for table $table."
            return 1
        else
            log_message "Successfully applied deduplicated rules for table $table."
        fi
    fi

    return 0
}


# --- Main Script Logic ---

# Guard execution based on argument parsing
if [[ $SAVE_ERROR -ne 0 ]]; then
    log_message "Skipping iptables save operation due to argument parsing error."
    exit 1
fi

# Ensure log directory exists (assuming $logs is set in global.env)
if [[ -z "${logs:-}" ]]; then
    handle_error "\$logs variable is not set. Cannot determine log path."
    exit 1
fi
mkdir -p "$(dirname "${logs}/firewall.log")" || { handle_error "Failed to create log directory"; exit 1; }


log_message "Starting iptables save operation"

# Deduplication process
tables=('filter' 'nat' 'mangle')
failed_tables=()

for table in "${tables[@]}"; do
    if ! dedup_improved "$table"; then
        failed_tables+=("$table")
        # dedup_improved already calls handle_error, so no need to call it again
    fi
done

if [[ ${#failed_tables[@]} -gt 0 ]]; then
    handle_error "Issues encountered while processing these tables: ${failed_tables[*]}"
fi

# Proceed only if no errors occurred during deduplication
if [ $SAVE_ERROR -eq 0 ]; then
    log_message "Saving current iptables rules to ${logs}/firewall.log"
    iptables-save >> "${logs}/firewall.log" || handle_error "Failed to save iptables rules to log"

    log_message "Saving current iptables rules to /etc/iptables.up.rules"
    iptables-save > /etc/iptables.up.rules || handle_error "Failed to save iptables rules to /etc/iptables.up.rules"
fi

# Log the completion of the save operation
if [ $SAVE_ERROR -eq 0 ]; then
    log_message "iptables save operation completed successfully"
else
    log_message "iptables save operation completed with errors"
fi

# Exit with status reflecting success or failure
exit $SAVE_ERROR
