#!/bin/bash
set -e

source $ENV_GLOBAL
source $ENV_NETWORK

# Import the ipset_process function
source $SCRIPTS/base/firewall/ipset_functions.sh

echo "Starting FireHOL ipset creation"

if ! ipset list FireHOL_lvl_1 >/dev/null 2>&1; then
    echo "Creating FireHOL_lvl_1 ipset"
    ipset create FireHOL_lvl_1 hash:net -exist
fi

file_path="$FIREHOL_NETSETS_PATH/FireHOL_lvl_1.netset"
if [ ! -f "$file_path" ]; then
    echo "Error: $file_path does not exist"
    exit 1
fi

firhole_ip_array=$(sed '/^#/d' "$file_path" | tr '\n' ' ' | sed 's/  */ /g')

if [ -z "$firhole_ip_array" ]; then
    echo "Error: No IPs found in $file_path"
    exit 1
fi

echo "Populating FireHOL_lvl_1 ipset"
ipset_process --label "FireHOL_lvl_1" --hash_type "net" --ip_array $firhole_ip_array --netset_path $FIREHOL_NETSETS_PATH

echo "FireHOL ipset creation complete"