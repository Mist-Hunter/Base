#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status.

source $ENV_NETWORK

export FIREHOL_NETSETS_PATH="/etc/firehol/ipsets"
mkdir -p "$FIREHOL_NETSETS_PATH"

echo "export FIREHOL_NETSETS_PATH=\"$FIREHOL_NETSETS_PATH\"" >> $ENV_NETWORK

ln -sf $SCRIPTS/base/firewall/ipset_firehol.sh /etc/network/if-pre-up.d/lan-nic.d/ipset_firehol.sh

echo "Running FireHOL updater..."
if ! . $SCRIPTS/base/firewall/firehol_updater.sh; then
    echo "Error: FireHOL updater failed"
    exit 1
fi

echo "Creating FireHOL service..."
if ! . $SCRIPTS/base/firewall/firehol_service_creation.sh; then
    echo "Error: Failed to create FireHOL service"
    exit 1
fi

echo "Running ipset_firehol.sh..."
if ! . $SCRIPTS/base/firewall/ipset_firehol.sh; then
    echo "Error: Failed to run ipset_firehol.sh"
    exit 1
fi

# Uncomment and adjust these rules as needed
# iptables -I INPUT -m set --match-set FireHOL_lvl_1 src -j DROP -m comment --comment "Block inbound from FireHOL_lvl_1 IPs"
# iptables -I OUTPUT -m set --match-set FireHOL_lvl_1 dst -j DROP -m comment --comment "Block outbound to FireHOL_lvl_1 IPs"

. $SCRIPTS/base/firewall/save.sh

echo "FireHOL installation complete."