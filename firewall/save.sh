#!/bin/bash
source $ENV_NETWORK

# TODO assure DROPS at bottom

# Check if FIREWALL is set to "none"
if [[ "$FIREWALL" == "none" ]]; then
    echo "FIREWALL is set to none. Exiting script."
    exit 1  # Exit with status code 1 (or any other status code you choose)
fi

# added by $(whoami) on $(date +"%Y-%m-%d @ %H:%M:%S")"
. $SCRIPTS/base/firewall/ipt-dedup.sh
touch $LOGS/firewall.log
echo -e "# scripts, apt, firewall, save to $IPTABLES_PERSISTENT_RULES: added by $(whoami) on $(date +"%Y-%m-%d @ %H:%M:%S")---------------------------------------" | tee -a $LOGS/firewall.log
iptables-save >> $LOGS/firewall.log
iptables-save > "$IPTABLES_PERSISTENT_RULES"
