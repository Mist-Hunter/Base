#!/bin/bash

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
        while [[ $line =~ $pattern ]]; do
            matched_part="${BASH_REMATCH[0]}"
            styled_part="${!color_name}${matched_part}${NC}"
            line="${line/${matched_part}/${styled_part}}"
        done
    done

    echo "$line"
}

log_tails() {

    # Define the log files to monitor
    local LOG_FILES=($(find "$LOGS" -type f \( -name "*.log" -o -name "*log.txt" \)))

    # Tail each log file and process each line
    for file in "${LOG_FILES[@]}"; do
        # Check if the file exists and is readable
        if [ -f "$file" ] && [ -r "$file" ]; then
            # Use tail and while loop to process each line
            tail -f "$file" | while IFS= read -r line; do
                log "$line" "$(basename "$file")"
            done &
            export tail_pids+=($!)
        else
            log "File '$file' does not exist or is not readable." "common/monitor_logs"
        fi
    done

}

log_stdout() {

    local caller_function="${FUNCNAME[1]}"
    local filename="${1:-$caller_function}"
    while IFS= read -r line; do
        log "$line" "$filename"
    done

}

present_secrets() {
    # Example: present_secrets "Root Password:p@ssw0rd123" "GRUB Password:grub123" "SSH Key:ssh-rsa AAAAB3NzaC1yc2E..."
    # present_secrets "Root Password:p@ssw0rd123" "GRUB Password:grub123" "SSH Key:ssh-rsa AAAAB3NzaC1yc2E..."
    # TODO include caller function and file path like log()

    local secrets=("$@")
    local term_width=$(($(tput cols) - 5))  # Subtract 5 for the scrollbar
    local separator_line=""
    local padding=2  # Padding on each side of the content

    # Create separator line
    separator_line=$(printf '%*s' "$term_width" | tr ' ' '-')

    # Print the ASCII block
    echo "$separator_line"
    printf "|%*s|\n" $((term_width - 2)) "" # Empty line at the start

    local first_pair=true
    for secret in "${secrets[@]}"; do
        IFS=':' read -r label value <<< "$secret"
        
        if [ "$first_pair" = true ]; then
            first_pair=false
        else
            printf "|%*s|\n" $((term_width - 2)) "" # Empty line between pairs
        fi

        printf "|%*s%-*s%*s|\n" "$padding" "" "$((term_width - padding * 2 - 2))" "$label:" "$padding" ""
        printf "|%*s%-*s%*s|\n" "$padding" "" "$((term_width - padding * 2 - 2))" "$value" "$padding" ""
    done

    printf "|%*s|\n" $((term_width - 2)) "" # Empty line at the end
    echo "$separator_line"

    # Wait for user to press ENTER
    read -p "Press [ENTER] to continue."
}

log() {
    local text=""

    # Find the correct caller script
    local i=1
    local caller_script
    local caller_function

    while [[ "${BASH_SOURCE[i]}" == */logging_functions.sh || "${BASH_SOURCE[i]}" == logging_functions.sh ]]; do
        ((i++))
    done

    # FIXME the next two FIXME's are related to log() being called from within this script
    # FIXME basename: invalid option -- 'b'
    # FIXME caller_function=main
    
    caller_script=$(basename "${BASH_SOURCE[i]:-$0}")
    caller_function="${FUNCNAME[i]:-main}"

    # Check if a single parameter is provided without flags
    if [[ $# -eq 1 && "$1" != --* ]]; then
        text="$1"
    else
        # Parse flags and set variables
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --text) text="$2"; shift 2 ;;
                --time) show_time="${2:-true}"; shift 2 ;;
                --date) show_date="${2:-false}"; shift 2 ;;
                --log_level) log_level="${2:-INFO}"; shift 2 ;;
                --show_function) show_function="${2:-true}"; shift 2 ;;
                --show_caller) show_caller="${2:-true}"; shift 2 ;;
                *) echo "Unknown option: $1"; return 1 ;;
            esac
        done
    fi

    # Exit if no text is provided
    [[ -z "$text" ]] && return

    local current_date=$(date "+%m/%d/%Y")
    local current_time=$(date "+%H:%M:%S")

    # Trim all whitespace characters, including newlines
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
    [[ "${show_date:-false}" == true ]] && formatted_line+="${current_date} "
    [[ "${show_time:-true}" == true ]] && formatted_line+="${current_time} "
    [[ "${show_caller:-true}" == true ]] && formatted_line+="[${caller_script}"
    [[ "${show_function:-true}" == true ]] && formatted_line+=" < ${caller_function}()] "
    [[ -n "${log_level:-INFO}" ]] && formatted_line+="${log_level:-INFO}"
    formatted_line+=": ${text}"

    local colored_line=$(colorize "$formatted_line")

    echo -e "$colored_line"
}

log_clean() {
    log "Starting log cleanup process..."

    # Define the number of days for gzip and deletion
    days_to_gzip=2
    days_to_delete=$((days_to_gzip * 2))

    # Gzip logs older than days_to_gzip
    find "$LOGS" -name "*.log" -type f -mtime +$days_to_gzip ! -name "*.gz" -exec gzip {} \;

    # Delete gzipped logs older than days_to_delete
    find "$LOGS" -name "*.gz" -mtime +$days_to_delete -delete

    log "Log cleanup process completed"
}

prompt() {
    echo "TODO"
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
                if [[ "$2" =~ ^[a-zA-Z_]+$ ]]; then  # If only a word, set default path
                    name="$2"
                    env_name="${name^^}"  # Uppercase version
                    path="${CONFIGS}/${name,,}.env"  # Lowercase path
                else
                    path="$2"
                    name=$(basename "$path" .env)
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
                echo "Unknown option: $1"
                return 1
                ;;
        esac
    done

    # Validate required arguments
    if [[ -z $path ]]; then
        echo "Error: --path is required."
        return 1
    fi

    # Write content to file
    echo -e "$content" | awk 'NR==1{print; next} {sub(/^[[:space:]]+/, ""); print}' > "$path"

    # Optionally update the global environment file
    if [[ $global == true ]]; then
        if ! grep -q "^export ENV_${env_name}=" "$ENV_GLOBAL"; then
            {
                echo "# $name"
                echo "export ENV_${env_name}=\"$path\""
                echo "source $path"
                echo ""
            } >> "$ENV_GLOBAL"
            log "Updated $ENV_GLOBAL with $name"
        else
            log "The global environment file already includes settings for $name."
        fi
    fi

    # Optionally source the file
    if [[ $source == true ]]; then
        source "$path"
    fi
}

