#!/bin/bash

# creation, saving, restoring, comparing and live swapping of ipsets

export NETSET_PATH="/etc/ipset"

# TODO implement iprange

# Create the ipset restore file
# if [ "${hash}" = "net" ]; then
#     iprange "${file}" \
#         --ipset-reduce ${IPSET_REDUCE_FACTOR} \
#         --ipset-reduce-entries ${IPSET_REDUCE_ENTRIES} \
#         --print-prefix "-A ${tmpname} " >"/tmp/${tmpname}"
#     entries=$( wc -l <"/tmp/${tmpname}" )
# elif [ "${hash}" = "ip" ]; then
#     iprange -1 "${file}" \
#         --print-prefix "-A ${tmpname} " >"/tmp/${tmpname}"
#     entries=${ips}
# fi
# echo "COMMIT" >>"/tmp/${tmpname}"

ipset_process() {
    local label=""
    local hash_type=""
    local ip_array=()
    local netset_path="${NETSET_PATH:-.}"

    # Parse command-line options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --label)
                label="$2"
                shift 2
                ;;
            --hash_type)
                hash_type="$2"
                shift 2
                ;;
            --ip_array)
                shift
                while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do
                    ip_array+=("$1")
                    shift
                done
                ;;
            --netset_path)
                netset_path="$2"
                shift 2
                ;;
            *)
                echo "Usage: $0 --label <label> --hash_type <hash_type> --ip_array <ip1> [<ip2> ...] [--netset_path <path>]"
                return 1
                ;;
        esac
    done

    # Validate required parameters
    if [[ -z "$label" || -z "$hash_type" ]]; then
        echo "Error: Missing required arguments"
        echo "Usage: $0 --label <label> --hash_type <hash_type> --ip_array <ip1> [<ip2> ...] [--netset_path <path>]"
        return 1
    fi

    local file_path="$netset_path/${label,,}.netset"
    local tmp_label="${label}_tmp"

    # Function to create a temporary ipset from IP array
    create_temp_ipset() {
        ipset create "$tmp_label" hash:"$hash_type" -exist
        IFS=$'\n' sorted_ips=($(printf "%s\n" "${ip_array[@]}" | sort -n -t. -k1,1 -k2,2 -k3,3 -k4,4))
        unset IFS
        for ip in "${sorted_ips[@]}"; do
            ipset add "$tmp_label" "$ip"
        done
    }

    # Create temporary ipset if IP array is provided
    if [[ ${#ip_array[@]} -gt 0 ]]; then
        create_temp_ipset
        new_content=$(ipset list "$tmp_label" --output save)
    fi

    # Check if the ipset already exists
    if ipset list "$label" &>/dev/null; then
        echo "ipset $label exists."
        current_content=$(ipset list "$label" --output save)
    else
        # Check if the file exists
        if [[ -f "$file_path" ]]; then
            echo "File found: $file_path"
            current_content=$(cat "$file_path")
            echo "Restoring ipset $label from $file_path"
            ipset restore < "$file_path"
        else
            echo "Creating new ipset $label with hash type $hash_type"
            ipset create "$label" hash:"$hash_type" -exist
            current_content=$(ipset list "$label" --output save)
        fi
    fi

    # Compare and swap if necessary
    if [[ -n "$new_content" && "$new_content" != "$current_content" ]]; then
        ipset swap "$tmp_label" "$label"
        ipset destroy "$tmp_label"
        echo "$new_content" > "$file_path"
        echo "Updated $file_path"
    elif [[ -n "$new_content" ]]; then
        echo "No changes detected for $label"
        ipset destroy "$tmp_label"
    fi

    # Clean up
    if [[ -n "$tmp_label" ]]; then
        ipset destroy "$tmp_label" 2>/dev/null
    fi
}
