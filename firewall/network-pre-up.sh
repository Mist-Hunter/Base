#!/bin/sh

# FIXME ETH2 needs to be replace with PRIMARY_NIC or whatever $LAN_NIC has become

# Debian 11 runs direct from: /etc/network/if-pre-up.d/iptables, Debian 12 via SystemD Service, $INVOCATION_ID or $LISTEN_PID = Run by SystemD
if [ "$IFACE" = "ETH2" ] || [ -n "$INVOCATION_ID" ] || [ -n "$LISTEN_PID" ]; then
  if [ -n "$INVOCATION_ID" ] || [ -n "$LISTEN_PID" ]; then
    echo "iptables persistence, pre-up, SystemD"
  else
    echo "iptables persistence, pre-up, interface $IFACE"
  fi
  ipset -N BOGONS nethash
  ipset --add BOGONS 0.0.0.0/8  # self-identification [RFC5735]                                                                                                                                        
  ipset --add BOGONS 10.0.0.0/8  # Private-Use Networks [RFC1918]                                                                                                                                      
  ipset --add BOGONS 169.254.0.0/16  # Link Local [RFC5735]
  ipset --add BOGONS 172.16.0.0/12  # Private-Use Networks [RFC1918]
  ipset --add BOGONS 192.0.0.0/24  # IANA IPv4 Special Purpose Address Registry [RFC5736]
  ipset --add BOGONS 192.0.2.0/24   # TEST-NET-1 [RFC5737]
  ipset --add BOGONS 192.168.0.0/16  # Private-Use Networks [RFC1918]
  ipset --add BOGONS 192.88.99.0/24  # 6to4 Relay Anycast [RFC3068]
  ipset --add BOGONS 198.18.0.0/15  # Network Interconnect Device Benchmark Testing [RFC5735]
  ipset --add BOGONS 198.51.100.0/24  # TEST-NET-2 [RFC5737]
  ipset --add BOGONS 203.0.113.0/24  # TEST-NET-3 [RFC5737]

  # TODO Instantiate variable variable IPSETS $ENV_* > *_FQDN so rules restore doesn't error.

  # TODO Restore FireHOL_level1
  $SCRIPTS/base/firewall/firehol_ipset_apply.sh "/firehol_level1.netset//firehol_level1.netset"

  # FIXME is this early enough to not be open?
  /sbin/iptables-restore < /etc/iptables.up.rules
fi