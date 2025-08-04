#!/usr/bin/env bash

# Description: This script saves the current iptables rules, safely deduplicates them while preserving rule order, and verifies the changes.
#              It can be executed directly or sourced by other scripts without exiting the parent shell.
# Usage: ./save.sh  OR  . ./save.sh
# Dependencies: iptables, iptables-save, iptables-restore, awk

set -uo pipefail

# Initialize error flag
SAVE_ERROR=0

# Function to log messages
log_message() {
    local message="$1"
    local timestamp
    timestamp=$(date +"%Y-%m-%d @ %H:%M:%S")
    echo "# scripts, apt, firewall, save: added by $(whoami) on ${timestamp} - ${message}"
}

# Function to handle errors
handle_error() {
    local error_message="$1"
    log_message "ERROR: $error_message"
    SAVE_ERROR=1
}

# Processes a given iptables table to find and remove duplicate rules.
deduplicate_table_rules() {
    local table=$1
    log_message "Processing table: $table for deduplication"

    local temp_rules_file temp_restore_file
    temp_rules_file=$(mktemp)
    temp_restore_file=$(mktemp)

    if ! iptables-save -t "$table" > "$temp_rules_file"; then
        handle_error "Failed to save rules for table $table."
        rm -f "$temp_rules_file" "$temp_restore_file"
        return 1
    fi

    if ! grep -q '^-A' "$temp_rules_file"; then
        log_message "No append rules (-A) to process in table '$table'. Skipping."
        rm -f "$temp_rules_file" "$temp_restore_file"
        return 0
    fi
    
    local non_append_lines
    non_append_lines=$(grep -v '^-A' "$temp_rules_file")
    local append_rules
    append_rules=$(grep '^-A' "$temp_rules_file")

    local deduped_append_rules
    deduped_append_rules=$(echo "$append_rules" | awk '!seen[$0]++')

    local original_rule_count
    original_rule_count=$(echo "$append_rules" | wc -l)
    local deduped_rule_count
    deduped_rule_count=$(echo "$deduped_append_rules" | wc -l)

    if [[ $original_rule_count -eq $deduped_rule_count ]]; then
        log_message "No duplicate -A rules found in $table table."
    else
        log_message "Deduplicated $table table: Found $((original_rule_count - deduped_rule_count)) duplicate -A rules."

        local duplicate_lines
        duplicate_lines=$(echo "$append_rules" | sort | uniq -d)
        if [[ -n "$duplicate_lines" ]]; then
            log_message "The following duplicate lines were found and will be consolidated:"
            echo "$duplicate_lines" | while IFS= read -r line; do
                log_message "  -> $line"
            done
        fi
        
        {
            echo "$non_append_lines" | grep -v '^COMMIT'
            echo "$deduped_append_rules"
            echo "COMMIT"
        } > "$temp_restore_file"
        
        log_message "Applying deduplicated rules for table $table..."

        if ! iptables-restore --table="$table" < "$temp_restore_file"; then
            handle_error "Failed to apply deduplicated rules for table $table."
            rm -f "$temp_rules_file" "$temp_restore_file"
            return 1
        else
            log_message "Successfully applied deduplicated rules for table $table."
            
            log_message "Verifying removal of duplicates from live ruleset..."
            local remaining_dupes
            remaining_dupes=$(iptables-save -t "$table" | grep '^-A' | sort | uniq -d)

            if [[ -z "$remaining_dupes" ]]; then
                log_message "Verification successful: No remaining duplicates found in table '$table'."
            else
                handle_error "Verification FAILED: Duplicates still exist in table '$table'."
                rm -f "$temp_rules_file" "$temp_restore_file"
                return 1
            fi
        fi
    fi

    rm -f "$temp_rules_file" "$temp_restore_file"
    return 0
}

# Main function to contain the script's primary logic.
main() {
    # Temporarily disable the shell's DEBUG trap to prevent interference.
    local old_debug_trap
    old_debug_trap=$(trap -p DEBUG || true)
    trap - DEBUG

    # Ensure the original DEBUG trap is restored when this function returns.
    trap "$old_debug_trap" RETURN

    local GLOBAL_ENV_FILE="/root/.config/global.env"

    if [[ ! -f "$GLOBAL_ENV_FILE" ]]; then
        echo "ERROR: Global environment file not found: $GLOBAL_ENV_FILE" >&2
        return 1
    fi
    
    # shellcheck disable=SC1090
    source "$GLOBAL_ENV_FILE"

    if [[ -z "${logs:-}" ]]; then
        handle_error "\$logs variable is not set. Cannot determine log path."
        return 1
    fi

    mkdir -p "$(dirname "${logs}/firewall.log")" || { handle_error "Failed to create log directory"; return 1; }

    log_message "Starting iptables save operation"

    local tables=('filter' 'nat' 'mangle')
    local failed_tables=()

    for table in "${tables[@]}"; do
        if ! deduplicate_table_rules "$table"; then
            failed_tables+=("$table")
        fi
    done

    if [[ ${#failed_tables[@]} -gt 0 ]]; then
        handle_error "Issues encountered while processing these tables: ${failed_tables[*]}"
    fi

    if [ $SAVE_ERROR -eq 0 ]; then
        log_message "Saving current iptables rules to ${logs}/firewall.log"
        iptables-save >> "${logs}/firewall.log" || handle_error "Failed to save iptables rules to log"

        log_message "Saving current iptables rules to /etc/iptables.up.rules"
        iptables-save > /etc/iptables.up.rules || handle_error "Failed to save iptables rules to /etc/iptables.up.rules"
    fi

    if [ $SAVE_ERROR -eq 0 ]; then
        log_message "iptables save operation completed successfully"
    else
        log_message "iptables save operation completed with errors"
    fi

    return $SAVE_ERROR
}

# Call the main function to run the script's logic.
main
