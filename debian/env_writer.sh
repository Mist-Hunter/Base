#!/bin/bash

env_writer() {
    local service_name=""
    local config_content=""
    local add_source=false
    local ENV_GLOBAL="${ENV_PATH}/global.env"

    # Function to display usage
    usage() {
        echo "Usage: $0 [--source] --service <service_name> --content <config_content>"
        exit 1
    }

    # Parse command line arguments
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --source) add_source=true ;;
            --service) service_name="$2"; shift ;;
            --content) config_content="$2"; shift ;;
            *) usage ;;
        esac
        shift
    done

    # Validate required arguments
    if [[ -z "$service_name" ]] || [[ -z "$config_content" ]]; then
        usage
    fi

    # Generate file paths and names
    local service_env="${ENV_PATH}/$(echo "$service_name" | tr '[:upper:]' '[:lower:]').env"
    local env_var_name="${service_name^^}"  # Uppercase version

    # Create the configuration directory if it doesn't exist
    mkdir -p "$(dirname "$service_env")"

    # Check if the global environment file exists
    if [[ ! -f "$ENV_GLOBAL" ]]; then
        echo "Global environment file $ENV_GLOBAL does not exist. Creating it..."
        touch "$ENV_GLOBAL"
        chmod 644 "$ENV_GLOBAL"
    fi

    # Write the environment variables to the service-specific file
    echo "Writing environment variables for service: $service_name"
    cat <<EOT > "$service_env"
${config_content}
EOT
    chmod 600 "$service_env"

    # Check if service_name is not 'GLOBAL'
    if [[ "$service_name" != "GLOBAL" ]]; then
        # Update the global environment file to source the service-specific environment file
        if ! grep -q "^export ENV_${env_var_name}=" "$ENV_GLOBAL"; then
            echo "# $service_name" >> "$ENV_GLOBAL"
            echo "export ENV_${env_var_name}=\"$service_env\"" >> "$ENV_GLOBAL"
            if $add_source; then
                echo "source $service_env" >> "$ENV_GLOBAL"
            fi
            echo "" >> "$ENV_GLOBAL"
            echo "Updated global environment file: $ENV_GLOBAL"
        else
            echo "The global environment file already includes settings for $service_name."
        fi
    fi

    # Source the file
    source "$service_env"

    echo "Environment variables for $service_name have been written and sourced."
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
