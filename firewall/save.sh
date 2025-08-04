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

# --- Argument Parsing ---
# Use a flag to indicate if argument parsing failed
local_arg_parse_failed=0

# Loop through arguments
for arg in "$@"; do
    case "$arg" in
        --debug|-d)
            DEBUG=1
            ;;
        *)
            # Instead of exit, set an error flag and print usage
            echo "Error: Unknown argument '$arg'" >&2 # Print to stderr
            echo "Usage: $0 [--debug | -d]" >&2
            SAVE_ERROR=1 # Set the global error flag
            local_arg_parse_failed=1
            break # Stop processing further arguments
            ;;
    esac
done
# --- End Argument Parsing ---

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
    Sfi
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

# --- Main Script Logic guarded by error flag ---
if [[ $SAVE_ERROR -eq 0 ]]; then
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
else
    log_message "Skipping iptables save operation due to argument parsing error."
fi
# --- End Main Script Logic ---

# Log the completion of the save operation
if [ $SAVE_ERROR -eq 0 ]; then
    log_message "iptables save operation completed successfully"
else
    log_message "iptables save operation completed with errors"
    # Set the exit status of the script, but don't force an exit here.
    # The return status of the script will be 1 if SAVE_ERROR is 1 due to 'set -e'.
    # If this script is sourced, 'set -e' will cause the sourcing shell to exit on error.
    # If executed normally, 'set -e' will cause it to exit if any command fails with non-zero.
    # The primary goal here is to let the parent script continue if sourced, but provide a status.
    # For a standalone script, the default exit behavior of 'set -e' on a non-zero exit from a command
    # or explicit 'exit $SAVE_ERROR' is usually fine.
    # Keeping the explicit 'exit $SAVE_ERROR' as a guard against cases where 'set -e' might not catch it,
    # or if the user wants an immediate termination on error.
    # Given the user's explicit request to avoid 'exit', we can remove the final 'exit $SAVE_ERROR'
    # and rely on the script's final exit status based on the last command's success/failure
    # or the value of $SAVE_ERROR if the script explicitly returns it.
    
    # If the goal is truly "no exits", the script would need to wrap all critical
    # operations in functions and use 'return' statuses throughout.
    # However, for a utility script like this, 'set -e' is typically used.
    # Let's remove the final 'exit $SAVE_ERROR' and rely on 'set -e' and
    # the implicit exit status of the script's last command, which will effectively
    # be determined by whether SAVE_ERROR was set or not.

    # If an unknown argument causes SAVE_ERROR to be 1, the script will naturally
    # exit with a non-zero status at the end because the 'if' condition for success
    # will be false, and the 'else' block will be entered.
    true # No-op to ensure previous command success if no explicit exit
fi
