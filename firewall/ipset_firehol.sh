#!/bin/bash

source $ENV_GLOBAL
source $ENV_NETWORK

echo "Starting firehol"

ipset create FireHOL_lvl_1 hash:net -exist

# TODO get file version
. $SCRIPTS/base/firewall/firehol_updater.sh
# TODO get file version, did it change?

firhole_ip_array=$(cat "$file_path" | sed '/^#/d' | tr '\n' ' ' | sed 's/  */ /g')

ipset_process --label "FireHOL_lvl_1" --hash_type "net" --ip_array $firhole_ip_array

#. $SCRIPTS/base/firewall/firehol_ipset_apply.sh "$FIREHOL_NETSETS_PATH/FireHOL_lvl_1.netset"