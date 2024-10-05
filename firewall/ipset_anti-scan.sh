#!/bin/bash

source $ENV_NETWORK

echo "Starting anti-scan"

# up
# FIXME this may need to run elsewhere
# lan_nic_gateway=$(ip route show 0.0.0.0/0 dev $LAN_NIC | cut -d\  -f3)
# ipset create AntiScan_AllowList hash:ip
# ipset add AntiScan_AllowList $lan_nic_gateway

# pre-up
ipset create AntiScan_Offenders hash:ip family inet hashsize 32768 maxelem 65536 timeout 600
ipset create AntiScan_ScannedPorts hash:ip,port family inet hashsize 32768 maxelem 65536 timeout 60
