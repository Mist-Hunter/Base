#!/bin/bash

# TODO if not --source then don't use export?

# TODO create a sub function for writting contents thats automatically idempotent based on (unique) key_comment. Default will just be to append to --file assuring there's a space between last entry and new entry but should support options --comment that can be used for idempotence? Support 'Sections'
## sources, aliases

# Function: lineinfile
# Description: Ensures a specific key=value line exists in a file.
#              It handles existing, commented-out, and missing lines idempotently.
#
# Arguments:
#   $1: The path to the configuration file (e.g., /etc/login.defs)
#   $2: The key or variable name (e.g., PASS_MAX_DAYS)
#   $3: The desired value (e.g., 90)
#
function lineinfile() {
    local FILE="$1"
    local KEY="$2"
    local VALUE="$3"
    local NEW_LINE="${KEY} ${VALUE}"
    
    # Check if all required arguments are provided
    if [[ -z "$FILE" || -z "$KEY" || -z "$VALUE" ]]; then
        echo "Error: Missing arguments. Usage: lineinfile <file> <key> <value>" >&2
        return 1
    fi

    # 1. Check if the line exists and is correct
    if grep -q "^${KEY}[[:space:]]*${VALUE}" "$FILE"; then
        echo "PASS: '${KEY}' is already set correctly."
        return 0
    fi

    # 2. Check if the setting exists, either commented or with a wrong value
    #    The regex '^#?s*KEY' matches lines that are uncommented (starts with KEY) 
    #    or commented (starts with #) followed by KEY.
    if grep -q "^#\?[\t ]*${KEY}" "$FILE"; then
        # Use sed to replace the existing (or commented) line with the new line.
        # This handles both commented-out lines and incorrect values.
        # \1 captures the indentation before the key, if any.
        sed -i -E "s/^#?\s*(${KEY})\s*.*$/\1\t${VALUE}/" "$FILE"
        
        # Note: If the file uses spaces (like in login.defs) instead of tabs, 
        # the replacement can be adjusted to be more precise:
        # sed -i -E "s/^#?\s*(${KEY})\s*.*$/\1\t${VALUE}/" "$FILE"
        echo "UPDATED: '${KEY}' replaced or uncommented with value '${VALUE}'."
    else
        # 3. Setting is missing entirely. Append it to the end of the file.
        echo "${NEW_LINE}" >> "$FILE"
        echo "ADDED: '${KEY}' appended with value '${VALUE}'."
    fi
}

env_writer() {
    local serviceName=""
    local configContent=""
    local caddSource=false
    local ENV_GLOBAL="${CONFIGS}/global.env"

    # Function to display usage
    usage() {
        echo "Usage: $0 [--source] --service <serviceName> --content <configContent>"
        exit 1
    }

    # Parse command line arguments
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --source) caddSource=true ;;
            --service) serviceName="$2"; shift ;;
            --content) configContent="$2"; shift ;;
            *) usage ;;
        esac
        shift
    done

    # Validate required arguments
    if [[ -z "$serviceName" ]] || [[ -z "$configContent" ]]; then
        usage
    fi

    # Generate file paths and names
    local serviceEnv="${CONFIGS}/$(echo "$serviceName" | tr '[:upper:]' '[:lower:]').env"
    local envVarName="${serviceName^^}"  # Uppercase version

    # Create the configuration directory if it doesn't exist
    mkdir -p "$(dirname "$serviceEnv")"

    # Check if the global environment file exists
    if [[ ! -f "$ENV_GLOBAL" ]]; then
        echo "Global environment file $ENV_GLOBAL does not exist. Creating it..."
        touch "$ENV_GLOBAL"
        chmod 644 "$ENV_GLOBAL"
    fi

    # Write the environment variables to the service-specific file
    echo "Writing environment variables for service: $serviceName"
    cat <<EOT > "$serviceEnv"
${configContent}
EOT
    chmod 600 "$serviceEnv"

    # Check if serviceName is not 'GLOBAL'
    if [[ "$serviceName" != "GLOBAL" ]]; then
        # Update the global environment file to source the service-specific environment file
        if ! grep -q "^export ENV_${envVarName}=" "$ENV_GLOBAL"; then
            echo "# $serviceName" >> "$ENV_GLOBAL"
            echo "export ENV_${envVarName}=\"$serviceEnv\"" >> "$ENV_GLOBAL"
            if $caddSource; then
                echo "source $serviceEnv" >> "$ENV_GLOBAL"
            fi
            echo "" >> "$ENV_GLOBAL"
            echo "Updated global environment file: $ENV_GLOBAL"
        else
            echo "The global environment file already includes settings for $serviceName."
        fi
    fi

    # Source the file
    source "$serviceEnv"

    echo "Environment variables for $serviceName have been written and sourced."
}
