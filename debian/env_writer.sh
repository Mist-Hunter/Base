#!/bin/bash

# TODO if not --source then don't use export?

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

# Example usage:
env_writer \
--service 'exampleService' \
--content '
# Filepaths
export base="/root"
export scripts="/root/scripts"
export logs="/var/log"

# Support Functions
export FUNC_SUPPORT=/root/opt/support.sh
source $FUNC_SUPPORT
'
