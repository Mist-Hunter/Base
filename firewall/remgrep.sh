#!/bin/bash
FILTER=$1
source "$SCRIPTS/base/debian/logging_functions.sh"

log "Apt, firewall, remgrep.sh: Searching $FILTER:"
iptables -S | grep $FILTER || true

IFS=$'\n'
for rule in `iptables -S| grep $FILTER | sed -e 's/-A/-D/'`; do
    echo $rule | xargs iptables 
done

log "Apt, firewall, remgrep.sh: After removal"
iptables -S | grep $FILTER || true