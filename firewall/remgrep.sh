#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <filter>"
    exit 1
fi

FILTER="$1"
log "Searching for '$FILTER':"
matching_rules=$(iptables -S | grep -F -- "$FILTER" || true)

if [ -z "$matching_rules" ]; then
    log "No rules found matching '$FILTER'."
    exit 0
fi

echo "$matching_rules"

IFS=$'\n'
while read -r rule; do
    modified_rule=$(echo "$rule" | sed -e 's/^-A/-D/')
    log "Removing rule: $modified_rule"
    if ! iptables $modified_rule; then
        log "Warning: Failed to remove rule: $modified_rule"
    fi
done <<< "$matching_rules"

log "After removal:"
iptables -S | grep -F -- "$FILTER" || true