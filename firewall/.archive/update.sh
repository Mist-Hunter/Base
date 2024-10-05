#!/bin/bash

# Repair DNS Entries
. $SCRIPTS/base/firewall/updateDNS.sh

# Repair Gateway Refferenced Entries
read -p "Please enter the current (incorrect) gateway [default: 172.27.0.1]: " old_gateway
old_gateway=${old_gateway:-"172.27.0.1"}

. $SCRIPTS/base/firewall/get_gateway.sh

REMOVE_RULES="/tmp/iptables-remove.rules"
UPDATED_RULES="/tmp/iptables-updated.rules"

echo "Removing $old_gateway, putting in $GATEWAY"

iptables -S | grep "$old_gateway" > $REMOVE_RULES

cp $REMOVE_RULES $UPDATED_RULES

sed -i "s|$old_gateway|$GATEWAY|g" $UPDATED_RULES
sed -i 's/^../iptables -I/g' $UPDATED_RULES 

sed -i 's/^../iptables -D/g' $REMOVE_RULES

echo "Remove rules:"
cat $REMOVE_RULES

echo "Add rules:"
cat $UPDATED_RULES

source $REMOVE_RULES
source $UPDATED_RULES

rm $REMOVE_RULES
rm $UPDATED_RULES

# FIXME Update ENV files export REV_PROXY_FQDN="172.27.0.1"
sed -i "s|$old_gateway|$GATEWAY|g" $ENV_GLOBAL

. $SCRIPTS/base/firewall/save.sh

# Rerun Net-Select incase of different network Path
# FIXME this might not really work with Debian 12 source files anymore
SOURCES_LIST="/etc/apt/sources.list"
# cat $SOURCES_LIST
# netselect-apt -o $SOURCES_LIST
# cat $SOURCES_LIST