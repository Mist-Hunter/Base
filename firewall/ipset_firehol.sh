#!/bin/bash
set -e

source $ENV_GLOBAL
source $ENV_NETWORK

# Import the ipset_process function
source $SCRIPTS/base/firewall/ipset_functions.sh

firehol_set="BLOCK_LIST"

echo "Starting $firehol_set ipset creation"

if ! ipset list $firehol_set >/dev/null 2>&1; then
    echo "Creating $firehol_set ipset"
    ipset create $firehol_set hash:net -exist
fi


file_path="$FIREHOL_NETSETS_PATH/$firehol_set.netset"
if [ ! -f "$file_path" ]; then
    echo "Error: $file_path does not exist"
    exit 1
fi

firhole_ip_array=$(sed '/^#/d' "$file_path" | tr '\n' ' ' | sed 's/  */ /g')

if [ -z "$firhole_ip_array" ]; then
    echo "Error: No IPs found in $file_path"
    exit 1
fi

echo "Populating $firehol_set ipset"
ipset_process --label "$firehol_set" --hash_type "net" --ip_array $firhole_ip_array --netset_path $FIREHOL_NETSETS_PATH

echo "FireHOL ipset creation complete"