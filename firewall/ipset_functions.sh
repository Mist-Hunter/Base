#!/bin/bash
source "$ENV_NETWORK"

# Constants
IPSET_REDUCE_FACTOR=${IPSET_REDUCE_FACTOR:-20}
IPSET_REDUCE_ENTRIES=${IPSET_REDUCE_ENTRIES:-65535}

# Helper function for error handling
error_exit() {
    echo "Error: $1" >&2
    # exit 1
}

# Function to create a temporary ipset from IP array
create_temp_ipset() {
    local tmp_label="$1"
    local hash_type="$2"
    shift 2
    local ip_array=("$@")
    
    ipset create "$tmp_label" hash:"$hash_type" -exist || error_exit "Failed to create temporary ipset"
   
    if [ "$hash_type" = "netZZZSKIP" ]; then
        # FIXME unclear that iprange is helping
        # Firehol probably already does this according to sources online
        local original_count=${#ip_array[@]}
        printf '%s\n' "${ip_array[@]}" | iprange --ipset-reduce "$IPSET_REDUCE_FACTOR" \
            --ipset-reduce-entries "$IPSET_REDUCE_ENTRIES" \
            | while IFS= read -r line; do
                ipset add "$tmp_label" "$line" || echo "Warning: Failed to add $line to $tmp_label"
            done
        local post_count=$(ipset list "$tmp_label" | grep -c "^[0-9]")
        echo "original_count:$original_count, post_count=$post_count" 
    else
        printf '%s\n' "${ip_array[@]}" | sort -u | while IFS= read -r ip; do
            ipset add "$tmp_label" "$ip" || echo "Warning: Failed to add $ip to $tmp_label"
        done
    fi
}

ipset_process() {
    local label="" hash_type="" ip_array=() netset_path="${NETSET_PATH:-.}"
    # Parse command-line options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --label) label="$2"; shift 2 ;;
            --hash_type) hash_type="$2"; shift 2 ;;
            --ip_array) shift; while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do ip_array+=("$1"); shift; done ;;
            --netset_path) netset_path="$2"; shift 2 ;;
            *) error_exit "Invalid option: $1" ;;
        esac
    done

    # Validate required parameters
    [[ -z "$label" || -z "$hash_type" ]] && error_exit "Missing required arguments"

    # Ensure netset_path directory exists
    if [ ! -d "$netset_path" ]; then
        mkdir -p "$netset_path" || error_exit "Failed to create directory: $netset_path"
    fi

    local file_path="$netset_path/${label,,}.netset"
    local tmp_label="${label}_tmp"

    # Create temporary ipset if IP array is provided
    if [[ ${#ip_array[@]} -gt 0 ]]; then
        create_temp_ipset "$tmp_label" "$hash_type" "${ip_array[@]}"
        new_content=$(ipset list "$tmp_label" --output save)
    fi

    # Check if the ipset already exists
    if ipset list "$label" &>/dev/null; then
        echo "ipset $label exists."
        current_content=$(ipset list "$label" --output save)
    elif [[ -f "$file_path" ]]; then
        echo "Restoring ipset $label from $file_path"
        ipset restore < "$file_path" || error_exit "Failed to restore ipset from $file_path"
        current_content=$(cat "$file_path")
    else
        echo "Creating new ipset $label with hash type $hash_type"
        ipset create "$label" hash:"$hash_type" -exist || error_exit "Failed to create ipset $label"
        current_content=$(ipset list "$label" --output save)
    fi

    # Compare and swap if necessary
    if [[ -n "$new_content" && "$new_content" != "$current_content" ]]; then        
        if ! ipset swap "$tmp_label" "$label"; then
            echo "Failed to swap ipsets. Attempting to overwrite netset file."
            echo "$new_content" > "$file_path" || error_exit "Failed to write to $file_path"
        else
            current_content=$(ipset list "$label" --output save)
            echo "$current_content" > "$file_path" || error_exit "Failed to write to $file_path"
            echo "Updated $file_path"
        fi
    elif [[ -n "$new_content" ]]; then
        echo "No changes detected for $label"
    fi

    # Clean up
    ipset destroy "$tmp_label" 2>/dev/null
    
}