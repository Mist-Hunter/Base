#!/bin/bash

source $ENV_NETWORK

echo "Starting anti-scan"

# pre-up
ipset create AntiScan_Offenders hash:ip family inet hashsize 32768 maxelem 65536 timeout 600
ipset create AntiScan_ScannedPorts hash:ip,port family inet hashsize 32768 maxelem 65536 timeout 60
