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

# NOTE FireHOL_lvl_1 will take the place of blocking neighbor BOGONS and also blocks bad reputation in non-bogons.
. $SCRIPTS/base/firewall/remgrep.sh "BOGONS"
iptables -A OUTPUT -m set ! --match-set FireHOL_lvl_1 dst -p tcp --dport 80 -m comment --comment "apt, firewall, up.sh: Allow HTTP out, except to FireHOL_lvl_1. APT Package manager." -j ACCEPT
iptables -A OUTPUT -m set ! --match-set FireHOL_lvl_1 dst -p tcp --dport 443 -m comment --comment "apt, firewall, up.sh: Allow HTTPS out, except to FireHOL_lvl_1. APT Package manager." -j ACCEPT
iptables -A OUTPUT -m set ! --match-set FireHOL_lvl_1 dst -p tcp --dport 21 -m comment --comment "apt, firewall, up.sh: Allow FTP out, except to FireHOL_lvl_1. APT Package manager." -j ACCEPT

. $SCRIPTS/base/firewall/save.sh

echo "FireHOL installation complete."