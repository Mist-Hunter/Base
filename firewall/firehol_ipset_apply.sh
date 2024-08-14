#!/bin/bash

# From: https://github.com/firehol/firehol/blob/master/contrib/ipset-apply.sh

# This script can load any IPv4 ipset in kernel.
# It can also update existing (in kernel) ipsets.
# The source file can be whatever iprange accepts
# including IPs, CIDRs, ranges, hostnames, etc.

set -e  # Exit immediately if a command exits with a non-zero status.
set -u  # Treat unset variables as an error when substituting.

# Default values for iprange reduce mode
# which optimizes netsets for optimal
# kernel performance.
IPSET_REDUCE_FACTOR=20
IPSET_REDUCE_ENTRIES=65535

usage() {
    echo >&2 "Usage: $0 <full_path_to_ipset_file>"
    echo >&2 "This script can load any IPv4 ipset in kernel."
    echo >&2 "Provide a full path to an .ipset or .netset file to load."
    exit 1
}

cleanup() {
    # remove the temporary file
    rm -f "/tmp/${tmpname}" 2>/dev/null

    # destroy the temporary ipset
    ipset destroy "${tmpname}" 2>/dev/null || true

    if [ ${FINISHED:-0} -eq 0 ]; then
        echo >&2 "FAILED, sorry!"
        exit 1
    fi

    echo >&2 "OK, all done!"
    exit 1
}

# Check if required commands are available
for cmd in ipset iprange; do
    if ! command -v $cmd &> /dev/null; then
        echo >&2 "Error: $cmd is required but not installed. Please install it and try again."
        exit 1
    fi
done

# Parse arguments
if [ $# -ne 1 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

file="$1"
ipset=$(basename "${file%.*}")
tmpname="tmp-$$-${RANDOM}-$(date +%s)"
FINISHED=0

# Validate file
if [ ! -f "${file}" ]; then
    echo >&2 "Error: File not found: ${file}"
    exit 1
fi

# Determine hash type
case "${file}" in
    *.ipset) hash="ip" ;;
    *.netset) hash="net" ;;
    *) echo >&2 "Error: Unrecognized file extension. File should end with .ipset or .netset"; exit 1 ;;
esac

# Setup cleanup trap
trap cleanup EXIT SIGHUP SIGINT SIGTERM

# Check if ipset already exists
if ipset list -n | grep -q "^${ipset}$"; then
    exists="yes"
else
    exists="no"
fi

# Count entries and unique IPs
entries=$(iprange -C "${file}")
ips=${entries/*,/}

# Create the ipset restore file
if [ "${hash}" = "net" ]; then
    iprange "${file}" \
        --ipset-reduce ${IPSET_REDUCE_FACTOR} \
        --ipset-reduce-entries ${IPSET_REDUCE_ENTRIES} \
        --print-prefix "-A ${tmpname} " >"/tmp/${tmpname}"
    entries=$( wc -l <"/tmp/${tmpname}" )
elif [ "${hash}" = "ip" ]; then
    iprange -1 "${file}" \
        --print-prefix "-A ${tmpname} " >"/tmp/${tmpname}"
    entries=${ips}
fi
echo "COMMIT" >>"/tmp/${tmpname}"

# Print information
cat <<EOF

ipset     : ${ipset}
hash      : ${hash}
entries   : ${entries}
unique IPs: ${ips}
file      : ${file}
tmpname   : ${tmpname}
exists in kernel already: ${exists}

EOF

# Set options for large ipsets
opts=
if [ ${entries} -gt 65536 ]; then
    opts="maxelem ${entries}"
fi

# Create or update the ipset
if [ ${exists} = no ]; then
    echo >&2 "Creating the ${ipset} ipset..."
    ipset create "${ipset}" hash:${hash} ${opts}
fi

echo >&2 "Creating a temporary ipset..."
ipset create "${tmpname}" hash:${hash} ${opts}

echo >&2 "Loading the temporary ipset with the IPs in file ${file}..."
ipset restore <"/tmp/${tmpname}"

echo >&2 "Swapping the temporary ipset with ${ipset}, to activate it..."
ipset swap "${tmpname}" "${ipset}"

# let the cleanup handler know we did it
FINISHED=1