#!/bin/bash

echo "Starting anti-scan"

ipset create whitelisted hash:net #$echoheader create exception whitelist!\n\
# FIXME gateway not defined at pre-up
# ipset add whitelisted $GATEWAY #$echoheader add gateway to whitelist!\n\
ipset create port_scanners hash:ip family inet hashsize 32768 maxelem 65536 timeout 600 #$echoheader Offenders\n\
ipset create scanned_ports hash:ip,port family inet hashsize 32768 maxelem 65536 timeout 60 #$echoheader Scanned Ports\n\


