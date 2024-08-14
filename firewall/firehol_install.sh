#!/bin/bash

ln -sf $SCRIPTS/base/firewall/ipset_firehol.sh /etc/network/if-pre-up.d/lan-nic.d/ipset_firehol.sh

. $SCRIPTS/base/firewall/firehol_service_creation.sh
. $SCRIPTS/base/firewall/ipset_firehol.sh

# Block inbound connections from IPs in the FireHOL_lvl_1 ipset
iptables -A INPUT -m set --match-set FireHOL_lvl_1 src -m comment --comment "base, firewall, firehol_install.sh: Block inbound matches to ipset FireHOL_lvl_1." -j DROP

# Block outbound connections to IPs in the FireHOL_lvl_1 ipset
iptables -A OUTPUT -m set --match-set FireHOL_lvl_1 dst -m comment --comment "base, firewall, firehol_install.sh: Block outbound matches to ipset FireHOL_lvl_1." -j DROP

. $SCRIPTS/base/firewall/save.sh

cat <<EOT >> $ENV_NETWORK

# FireHOL
export FIREHOL_NETSETS_PATH="/etc/firehol/ipsets"
EOT
