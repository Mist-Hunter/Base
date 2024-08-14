#!/bin/bash

# Remove added rules
. $SCRIPTS/base/firewall/remgrep.sh "anti-scan.sh"

# Flush ipsets
ipset flush AntiScan_ScannedPorts
ipset flush AntiScan_Offenders 
ipset flush AntiScan_AllowList

# Remove added ipset lines from iptables script
rm /etc/network/if-pre-up.d/lan-nic.d/ipset_anti-scan.sh

# Reload firewall 
. $SCRIPTS/base/firewall/save.sh

echo "Reverted firewall changes"