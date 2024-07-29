#!/bin/sh
# From: https://gist.github.com/wallneradam/1e13c7bca1c7c984ee543a4e97089cf3

ipt="iptables -w"

dedup() {
    iptables-save | sed -n "/$1/,/COMMIT/p" | grep "^-" | sort | uniq -dc | while read l
    do
        c=$(echo "$l" | sed "s|^[ ]*\([0-9]*\).*$|\1|")
        rule=$(echo "$l" | sed "s|^[ ]*[0-9]* -A\(.*\)$|-t $1 -D\1|")
        while [ ${c} -gt 1 ]; do
            echo "iptables $rule"
            eval "${ipt} ${rule}"
            c=$((c-1))
        done
    done
}

dedup "filter"
dedup "nat"
dedup "mangle"

iptables-save > /etc/iptables.up.rules