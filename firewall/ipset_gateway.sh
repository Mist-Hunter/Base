#!/bin/bash

source $SCRIPTS/base/firewall/ipset_functions.sh

lan_nic_gateway=$(ip route show 0.0.0.0/0 dev $LAN_NIC | cut -d\  -f3)
# TODO add gateway to /etc/environtment & $ENV_NETWORK

ipset_process --label "GATEWAY" --hash_type "ip" --ip_array $lan_nic_gateway