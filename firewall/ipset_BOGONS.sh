#!/bin/bash

# At pre-up

source $ENV_GLOBAL
source $ENV_NETWORK

# Import the ipset_process function
source $SCRIPTS/base/firewall/ipset_functions.sh

echo "Starting BOGONS"

# Declare an array to hold the bogons
bogons_array="\
    0.0.0.0/8 `# self-identification [RFC5735]`
    10.0.0.0/8 `# Private-Use Networks [RFC1918]`
    169.254.0.0/16 `# Link Local [RFC5735]`
    172.16.0.0/12 `# Private-Use Networks [RFC1918]`
    192.0.0.0/24 `# IANA IPv4 Special Purpose Address Registry [RFC5736]`
    192.0.2.0/24 `# TEST-NET-1 [RFC5737]`
    192.168.0.0/16 `# Private-Use Networks [RFC1918]`
    192.88.99.0/24 `# 6to4 Relay Anycast [RFC3068]`
    198.18.0.0/15 `# Network Interconnect Device Benchmark Testing [RFC5735]`
    198.51.100.0/24 `# TEST-NET-2 [RFC5737]`
    203.0.113.0/24 `# TEST-NET-3 [RFC5737]`
"

ipset_process --label "BOGONS" --hash_type "net" --ip_array $bogons_array
ipset_process --label "BLOCK_LIST" --hash_type "net" --ip_array $bogons_array
