#!/bin/bash

source $ENV_GLOBAL
source $ENV_NETWORK

echo "Starting firehol"

ipset create FireHOL_lvl_1 hash:net -exist

. $SCRIPTS/base/firewall/firehol_ipset_apply.sh "${FIREHOL_NETSETS_PATH}/FireHOL_lvl_1.netset"