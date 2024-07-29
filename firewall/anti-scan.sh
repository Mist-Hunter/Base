#!/bin/bash
# https://www.toolbox.com/tech/operating-systems/question/how-to-block-port-scanning-tools-and-log-them-with-iptables-051115/
# https://serverfault.com/questions/941952/iptables-rules-and-port-scanners-blocking
# https://superuser.com/questions/1531696/blacklisting-port-scanner-via-iptables
# https://unix.stackexchange.com/questions/345114/how-to-protect-against-port-scanners
# >>> https://unix.stackexchange.com/a/407904 ***

# Be aware of that someone can make any IP blocked by just make scan as spoofing. I suggest you don't set block timeout too long.

# Check if FIREWALL is set to "none"
if [[ "$FIREWALL" == "none" ]]; then
    echo "FIREWALL is set to none. Exiting script."
    exit 1  # Exit with status code 1 (or any other status code you choose)
fi

echoheader="apt, firewall, anti-scan.sh:"

. $SCRIPTS/base/firewall/get_gateway.sh

# Make sure that crowdsec-blacklists is in /etc/network/if-pre-up.d/iptables script, or things will go haywire (rules fail to load)
if (! $(cat /etc/network/if-pre-up.d/iptables | grep -q "port_scanners")); then
echo "$echoheader ipset crowdsec-blacklists missing in /etc/network/if-pre-up.d/iptables"
sed -i "s/ipset -N BOGONS nethash/\
ipset create whitelisted hash:net #$echoheader create exception whitelist!\n\
ipset add whitelisted $GATEWAY #$echoheader add gateway to whitelist!\n\
ipset create port_scanners hash:ip family inet hashsize 32768 maxelem 65536 timeout 600 #$echoheader Offenders\n\
ipset create scanned_ports hash:ip,port family inet hashsize 32768 maxelem 65536 timeout 60 #$echoheader Scanned Ports\n\
ipset -N BOGONS nethash/g" /etc/network/if-pre-up.d/iptables
else
    echo "$echoheader ipset port_scanners present"
fi

ipset create whitelisted hash:net
ipset create port_scanners hash:ip family inet hashsize 32768 maxelem 65536 timeout 600
ipset create scanned_ports hash:ip,port family inet hashsize 32768 maxelem 65536 timeout 60

iptables -A INPUT -m conntrack --ctstate INVALID -m comment --comment "$echoheader Drop invalid packets" -j DROP
iptables -A INPUT -m conntrack --ctstate NEW -m set ! --match-set scanned_ports src,dst -m hashlimit --hashlimit-above 1/hour --hashlimit-burst 5 --hashlimit-mode srcip --hashlimit-name portscan --hashlimit-htable-expire 10000 -m comment --comment "$echoheader Add offenders to port_scanners" -j SET --add-set port_scanners src --exist
iptables -A INPUT -m conntrack --ctstate NEW -m set --match-set port_scanners src -m set ! --match-set whitelisted src -m comment --comment "$echoheader Drop packets from port_scanner members" -j DROP
iptables -A INPUT -m conntrack --ctstate NEW -m comment --comment "$echoheader Add scanner ports to scanned_ports" -j SET --add-set scanned_ports src,dst

. $SCRIPTS/base/firewall/save.sh
