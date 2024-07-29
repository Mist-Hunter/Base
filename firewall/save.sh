#!/bin/bash

# Check if FIREWALL is set to "none"
if [[ "$FIREWALL" == "none" ]]; then
    echo "FIREWALL is set to none. Exiting script."
    exit 1  # Exit with status code 1 (or any other status code you choose)
fi

# added by $(whoami) on $(date +"%Y-%m-%d @ %H:%M:%S")"
. $SCRIPTS/apt/firewall/ipt-dedup.sh
touch $LOGS/firewall.log
echo -e "# scripts, apt, firewall, save: added by $(whoami) on $(date +"%Y-%m-%d @ %H:%M:%S")---------------------------------------" | tee -a $LOGS/firewall.log
iptables-save >> $LOGS/firewall.log
iptables-save > /etc/iptables.up.rules
