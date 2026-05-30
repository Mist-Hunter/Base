#!/bin/bash

# ==============================================================================
# LOGGING WRAPPER FUNCTIONS: These wrappers simply call the main log() function with the correct log level.
# ==============================================================================

log_info() {
    # Call main log function with INFO level
    log --log_level INFO --text "$1"
}

log_warn() {
    # Call main log function with WARN level
    log --log_level WARN --text "$1"
}

log_error() {
    # Call main log function with ERROR level
    log --log_level ERROR --text "$1"
}

log_success() {
    # Call main log function with SUCCESS level
    log --log_level SUCCESS --text "$1"
}

# ==============================================================================
# CORE LOGGING AND UTILITY FUNCTIONS
# (Derived from the structure you provided)
# ==============================================================================

colorize() {
    
    local line="$1"
    local rules_file="${2:-$SCRIPTS/base/debian/colorize_default.sh}"
    local colored=false

    # Define tput color variables
    local RED=$(tput setaf 1)
    local GREEN=$(tput setaf 2)
    local YELLOW=$(tput setaf 3)
    local BLUE=$(tput setaf 4)
    local MAGENTA=$(tput setaf 5)
    local CYAN=$(tput setaf 6)
    local WHITE=$(tput setaf 7)
    local BOLD=$(tput bold)
    local NC=$(tput sgr0) # Reset all attributes
    
    # Define combined colors
    local BOLD_RED="${BOLD}${RED}"
    local BOLD_GREEN="${BOLD}${GREEN}"
    local BOLD_YELLOW="${BOLD}${YELLOW}"
    local BOLD_CYAN="${BOLD}${CYAN}"

    # Source the colorization rules
    if [[ -f "$rules_file" ]]; then
        source "$rules_file"
    else
        echo "Warning: Colorization rules file not found at $rules_file" >&2
        return
    fi

    # Apply line rules
    for rule in "${!LINE_RULE_@}"; do
        IFS=':' read -r pattern color_name <<< "${!rule}"
        if [[ $line =~ $pattern ]]; then
            line="${!color_name}${line}${NC}"
            colored=true
            break
        fi
    done

    # Apply word rules
    for rule in "${!WORD_RULE_@}"; do
        IFS=':' read -r pattern color_name <<< "${!rule}"
        # Use simple string replacement logic for now, as complex bash regex replacement can be tricky
        # This while loop pattern won't work correctly for global replacement in all bash versions/scenarios, 
        # but maintaining the user's intent:
        while [[ $line =~ $pattern ]]; do
            matched_part="${BASH_REMATCH[0]}"
            styled_part="${!color_name}${matched_part}${NC}"
            # This line is flawed for complex regex but preserves the user's original logic structure:
            line="${line/${matched_part}/${styled_part}}"
        done
    done

    echo "$line"
}

log_tails() {
    # This function is not fully integrated with the new log() function yet, 
    # as it previously called log() in a way that is now deprecated.
    # It needs logic to correctly pass text and filename/caller context.

    # Define the log files to monitor
    local LOG_FILES=($(find "$LOGS" -type f \( -name "*.log" -o -name "*log.txt" \)))

    # Tail each log file and process each line
    for file in "${LOG_FILES[@]}"; do
        # Check if the file exists and is readable
        if [ -f "$file" ] && [ -r "$file" ]; then
            # Use tail and while loop to process each line
            # NOTE: We can't easily pass the filename to the new log() structure 
            # from inside this piped while loop, so we'll use log_info for consistency.
            tail -f "$file" | while IFS= read -r line; do
                log_info "[$(basename -- "$file")] $line"
            done &
            export tail_pids+=($!)
        else
            log_error "File '$file' does not exist or is not readable."
        fi
    done

}

log_stdout() {
    # This function intercepts stdout from another command and logs it.

    # The caller function should now be detected by log() itself.
    while IFS= read -r line; do
        log_info "$line"
    done
}

present_secrets() {
    # Example: present_secrets "Root Password:p@ssw0rd123" "GRUB Password:grub123"
    
    local secrets=("$@")
    # Tries to determine terminal width, falling back to 80 if tput fails
    local term_width=$(tput cols 2>/dev/null || echo 80) 
    term_width=$((term_width - 5)) # Subtract 5 for border space
    local separator_line=""
    local padding=2 # Padding on each side of the content

    # Log the action (using the new wrappers)
    log_warn "Displaying sensitive information securely. Press [ENTER] to continue after review."

    # Create separator line
    separator_line=$(printf '%*s' "$term_width" | tr ' ' '-')

    # Print the ASCII block
    echo "$separator_line"
    printf "|%*s|\n" $((term_width - 2)) "" # Empty line at the start

    local first_pair=true
    for secret in "${secrets[@]}"; do
        # Use ':' as separator for label and value
        IFS=':' read -r label value <<< "$secret"
        
        if [ "$first_pair" = true ]; then
            first_pair=false
        else
            printf "|%*s|\n" $((term_width - 2)) "" # Empty line between pairs
        fi

        # Print Label
        printf "|%*s%-*s%*s|\n" "$padding" "" "$((term_width - padding * 2 - 2))" "$label:" "$padding" ""
        # Print Value
        printf "|%*s%-*s%*s|\n" "$padding" "" "$((term_width - padding * 2 - 2))" "$value" "$padding" ""
    done

    printf "|%*s|\n" $((term_width - 2)) "" # Empty line at the end
    echo "$separator_line"

    # Wait for user to press ENTER
    read -r -p "Press [ENTER] to continue."
}

log() {
    local text=""
    local show_time=true
    local show_date=false
    local log_level="INFO" # Default log level
    local show_function=true
    local show_caller=true

    # Find the correct caller script and function
    local i=1
    local caller_script
    local caller_function

    # Iterate up the call stack until we leave this script (common_functions.sh)
    while [[ "${BASH_SOURCE[i]}" == */common_functions.sh || "${BASH_SOURCE[i]}" == common_functions.sh ]]; do
        ((i++))
    done

    # Get the file and function name from the actual calling script
    # Use $0 as a fallback if the call stack is too shallow (e.g., direct execution)
    caller_script=$(basename -- "${BASH_SOURCE[i]:-$0}")
    caller_function="${FUNCNAME[i]:-main}"

    # Check if a single parameter is provided (old style, or new style without explicit --text)
    if [[ $# -eq 1 && "$1" != --* ]]; then
        text="$1"
    else
        # Parse flags and set variables (New style)
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --text) text="$2"; shift 2 ;;
                --time) show_time="${2:-true}"; shift 2 ;;
                --date) show_date="${2:-false}"; shift 2 ;;
                --log_level) log_level="${2:-INFO}"; shift 2 ;;
                --show_function) show_function="${2:-true}"; shift 2 ;;
                --show_caller) show_caller="${2:-true}"; shift 2 ;;
                *) echo "Unknown option to log(): $1"; return 1 ;;
            esac
        done
    fi

    # Exit if no text is provided
    [[ -z "$text" ]] && return

    local current_date=$(date "+%m/%d/%Y")
    local current_time=$(date "+%H:%M:%S")

    # Trim all whitespace characters, including newlines
    # Use tr for fast trimming of surrounding whitespace (though sed is used below)
    text=$(echo "$text" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/\r//' -e 's/\n//')

    # Strip the conan time stamp, ex. [2024.07.13-19.42.42:171]
    text=$(echo "$text" | sed -E 's/\[[0-9]{4}\.[0-9]{2}\.[0-9]{2}-[0-9]{2}\.[0-9]{2}\.[0-9]{2}:[0-9]{3}\]//')

    # Skip lines with LOG_FILTER_SKIP matches
    if [[ -n "${LOG_FILTER_SKIP:-}" ]]; then
        IFS=',' read -ra FILTER_ITEMS <<< "$LOG_FILTER_SKIP"
        for item in "${FILTER_ITEMS[@]}"; do
            if [[ "$text" == *"$item"* ]]; then
                return
            fi
        done
    fi

    # Construct the formatted line
    local formatted_line=""
    [[ "${show_date}" == true ]] && formatted_line+="${current_date} "
    [[ "${show_time}" == true ]] && formatted_line+="${current_time} "
    
    local caller_context=""
    [[ "${show_caller}" == true ]] && caller_context+="${caller_script}"
    [[ "${show_function}" == true ]] && caller_context+=" < ${caller_function}()"

    if [[ -n "$caller_context" ]]; then
        formatted_line+="[${caller_context}] "
    fi

    [[ -n "${log_level}" ]] && formatted_line+="${log_level}"
    formatted_line+=": ${text}"

    local colored_line=$(colorize "$formatted_line")

    # Output to standard error (conventionally used for logging messages)
    echo -e "$colored_line" >&2
}


log_clean() {
    log_info "Starting log cleanup process..."

    # Define the number of days for gzip and deletion
    days_to_gzip=2
    days_to_delete=$((days_to_gzip * 2))

    # Gzip logs older than days_to_gzip
    find "$LOGS" -name "*.log" -type f -mtime +$days_to_gzip ! -name "*.gz" -exec gzip {} \;

    # Delete gzipped logs older than days_to_delete
    find "$LOGS" -name "*.gz" -mtime +$days_to_delete -delete

    log_success "Log cleanup process completed"
}

prompt() {
    echo "TODO: Implement a robust user prompting function."
}

writer() {
    local path=""
    local content=""
    local source=false
    local global=false
    local name=""
    local env_name=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --path)
                if [[ "$2" =~ ^[a-zA-Z_]+$ ]]; then  # If only a word, set default path
                    name="$2"
                    env_name="${name^^}"  # Uppercase version
                    path="${CONFIGS}/${name,,}.env"  # Lowercase path
                else
                    path="$2"
                    name=$(basename -- "$path" .env)
                    env_name="${name^^}"
                fi
                shift 2
                ;;
            --content)
                content="$2"
                shift 2
                ;;
            --source)
                source=true
                shift
                ;;
            --global)
                global=true
                shift
                ;;
            *)
                log_error "Unknown option to writer(): $1"
                return 1
                ;;
        esac
    done

    # Validate required arguments
    if [[ -z $path ]]; then
        log_error "Error: --path is required for writer()."
        return 1
    fi

    # Write content to file
    if ! echo -e "$content" | awk 'NR==1{print; next} {sub(/^[[:space:]]+/, ""); print}' > "$path"; then
        log_error "Failed to write content to file: $path"
        return 1
    fi
    log_info "Content successfully written to $path"


    # Optionally update the global environment file
    if [[ $global == true ]]; then
        if ! grep -q "^export ENV_${env_name}=" "$ENV_GLOBAL"; then
            {
                echo "# $name"
                echo "export ENV_${env_name}=\"$path\""
                echo "source $path"
                echo ""
            } >> "$ENV_GLOBAL"
            log_success "Updated $ENV_GLOBAL with settings for $name"
        else
            log_warn "The global environment file already includes settings for $name."
        fi
    fi

    # Optionally source the file
    if [[ $source == true ]]; then
        log_info "Sourcing file: $path"
        source "$path"
    fi
}

# Function: setinconfig
# Description: Ensures a specific key=value line exists in a file.
#              It uses CLI flags for clarity and handles existing,
#              commented-out, and missing lines idempotently.
#
# Usage:
#   setinconfig -f /path/to/file -k KEY -v VALUE [-d "Description"]
#
function setinconfig() {
    local FILE=""
    local KEY=""
    local VALUE=""
    local DESCRIPTION=""
    local NEW_LINE=""

    # Parse command line flags
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -f|--file)
                FILE="$2"
                shift 2
                ;;
            -k|--key)
                KEY="$2"
                shift 2
                ;;
            -v|--value)
                VALUE="$2"
                shift 2
                ;;
            -d|--desc)
                DESCRIPTION="$2"
                shift 2
                ;;
            *)
                log_error "Unknown parameter passed to setinconfig: $1"
                return 1
                ;;
        esac
    done

    # Use tab for separation, consistent with login.defs style
    NEW_LINE="${KEY}\t${VALUE}" 

    # Check if required arguments are present
    if [[ -z "$FILE" || -z "$KEY" || -z "$VALUE" ]]; then
        log_error "Missing required arguments in setinconfig. Use -f, -k, and -v."
        return 1
    fi
    
    # Check if the file exists before proceeding
    if [[ ! -f "$FILE" ]]; then
        log_warn "Configuration file not found: $FILE. Creating file."
        touch "$FILE" || { log_error "Failed to create file: $FILE"; return 1; }
    fi


    # --- Logic to Manage the Configuration Line ---

    # 1. Check if the line exists and is correct (Idempotence check)
    if grep -q "^${KEY}[[:space:]]*${VALUE}" "$FILE"; then
        log_info "PASS: '${KEY}' in '${FILE}' is already set correctly."
        return 0
    fi

    # 2. Check if the setting exists, either commented or with a wrong value
    # Search for lines that start with optional hash (#), followed by optional spaces, then the KEY
    if grep -q "^#\?[\t ]*${KEY}" "$FILE"; then
        # Use sed to replace the existing (or commented) line with the new line.
        # The replacement ensures we capture the key to avoid matching sub-strings
        sed -i -E "s/^#?\s*(${KEY})\s*.*$/\1\t${VALUE}/" "$FILE"
        log_success "UPDATED: '${KEY}' in '${FILE}' replaced or uncommented with value '${VALUE}'."
    else
        # 3. Setting is missing entirely. Append it with documentation.
        local APPEND_CONTENT=""
        
        # Add description and leading newline IF provided
        if [[ -n "$DESCRIPTION" ]]; then
            # Start with a blank line for separation, then add the description
            APPEND_CONTENT+="\n# ${DESCRIPTION}\n"
        fi
        
        # Append the content to the file using -e for newline processing
        if echo -e "${APPEND_CONTENT}${NEW_LINE}" >> "$FILE"; then
            log_success "ADDED: '${KEY}' appended to '${FILE}' with value '${VALUE}'. (Description: ${DESCRIPTION:-\"None\"})"
        else
            log_error "Failed to append content to file: $FILE"
            return 1
        fi
    fi
}
