#!/bin/bash

# FIXME variable remote IPs @ Github are breaking IPSet method require next line hack
. $SCRIPTS/base/firewall/ipset_fqdn_env_to_ipset.sh

find "$SCRIPTS" -type d -name ".git" -exec sh -c '
    # Iterate over each found .git directory
    for dir; do
        # Get the parent directory and pull updates
        echo "Pulling updates in $(dirname "$dir")..."
        git -C "$(dirname "$dir")" pull
    done
' _ {} +