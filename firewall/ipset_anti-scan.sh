#!/bin/bash

echo "Starting anti-scan"

# up
ipset create AntiScan_AllowList hash:net
ipset add AntiScan_AllowList $GATEWAY

# pre-up
ipset create AntiScan_Offenders hash:ip family inet hashsize 32768 maxelem 65536 timeout 600
ipset create AntiScan_ScanedPorts hash:ip,port family inet hashsize 32768 maxelem 65536 timeout 60


