#!/bin/bash

# Remove added rules
. $SCRIPTS/base/firewall/remgrep.sh "anti-scan.sh"

# Flush ipsets
ipset flush scanned_ports
ipset flush port_scanners 
ipset flush whitelisted

# Remove added ipset lines from iptables script
cat /etc/network/if-pre-up.d/iptables 
sed -i '/anti-scan.sh/d' /etc/network/if-pre-up.d/iptables  
cat /etc/network/if-pre-up.d/iptables 

# Reload firewall 
. $SCRIPTS/base/firewall/save.sh

echo "Reverted firewall changes"