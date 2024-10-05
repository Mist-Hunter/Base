#!/bin/bash
# https://www.toolbox.com/tech/operating-systems/question/how-to-block-port-scanning-tools-and-log-them-with-iptables-051115/
# https://serverfault.com/questions/941952/iptables-rules-and-port-scanners-blocking
# https://superuser.com/questions/1531696/blacklisting-port-scanner-via-iptables
# https://unix.stackexchange.com/questions/345114/how-to-protect-against-port-scanners
# >>> https://unix.stackexchange.com/a/407904 ***

# Be aware of that someone can make any IP blocked by just make scan as spoofing. I suggest you don't set block timeout too long.

source $ENV_NETWORK

# Check if FIREWALL is set to "none"
if [[ "$FIREWALL" == "none" ]]; then
    echo "FIREWALL is set to none. Exiting script."
    exit 1  # Exit with status code 1 (or any other status code you choose)
fi

ln -sf $SCRIPTS/base/firewall/ipset_anti-scan.sh /etc/network/if-pre-up.d/lan-nic.d/ipset_anti-scan.sh

OFFENDER_TIMER=600

ipset create AntiScan_AllowList hash:net
ipset create AntiScan_Offenders hash:ip family inet hashsize 32768 maxelem 65536 timeout $OFFENDER_TIMER
ipset create AntiScan_ScannedPorts hash:ip,port family inet hashsize 32768 maxelem 65536 timeout 60

iptables -A INPUT -m conntrack --ctstate INVALID -m comment --comment "apt, firewall, anti-scan.sh: Drop invalid packets" -j DROP
iptables -I INPUT -m conntrack --ctstate NEW -m set ! --match-set AntiScan_ScannedPorts src,dst -m hashlimit --hashlimit-above 1/hour --hashlimit-burst 5 --hashlimit-mode srcip --hashlimit-name portscan --hashlimit-htable-expire 10000 -m comment --comment "apt, firewall, anti-scan.sh: Add offenders to AntiScan_Offenders" -j SET --add-set AntiScan_Offenders src --exist
# FIXME drop rules should only be added to default ALLOW chains! (not needed otherwise)
## NOTE drop rules could still help, if placed above ACCEPT rules
iptables -A INPUT -m conntrack --ctstate NEW -m set --match-set AntiScan_Offenders src -m set ! --match-set AntiScan_AllowList src -m comment --comment "apt, firewall, anti-scan.sh: Drop packets from port_scanner members" -j DROP
iptables -I INPUT -m conntrack --ctstate NEW -m comment --comment "apt, firewall, anti-scan.sh: Add scanner ports to AntiScan_ScannedPorts" -j SET --add-set AntiScan_ScannedPorts src,dst

. $SCRIPTS/base/firewall/save.sh

# TODO create anti-scan notification service, will need to interact on a interval matching $OFFENDER_TIMER