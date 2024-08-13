#!/bin/bash

# Debian 11 runs direct from: /etc/network/if-pre-up.d/iptables, Debian 12 via SystemD Service, $INVOCATION_ID or $LISTEN_PID = Run by SystemD
if [ "$IFACE" = "ETH2" ] || [ -n "$INVOCATION_ID" ] || [ -n "$LISTEN_PID" ]; then
  if [ -n "$INVOCATION_ID" ] || [ -n "$LISTEN_PID" ]; then
    echo "iptables persistence, if-up, SystemD"
  else
    echo "iptables persistence, if-up, interface $IFACE"
  fi

  # TODO populate variable IPSETS $ENV_* > *_FQDN
  # TODO populate FireHOL_level1 (handled by SystemD service)

fi