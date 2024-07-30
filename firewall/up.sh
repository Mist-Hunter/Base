#!/bin/bash

#The Network
#Best installed first due to later exceptions that refference this package.
#https://github.com/imthenachoman/How-To-Secure-A-Linux-Server/blob/master/README.md#firewall-with-ufw-uncomplicated-firewall

# What is the first adapter after loopback?
# https://stackoverflow.com/questions/19227781/linux-getting-all-network-interface-names
# https://unix.stackexchange.com/questions/29878/can-i-access-nth-line-number-of-standard-output
# https://superuser.com/questions/203272/list-only-the-device-names-of-all-available-network-interfaces
# Return name of second network interface per ip -o link show

# Check if FIREWALL is set to "none"
# FIXME still getting prompted to install scanner (bottom) when set to none
if [[ "$FIREWALL" == "none" ]]; then
    echo "FIREWALL is set to none. Exiting script."
    exit 1  # Exit with status code 1 (or any other status code you choose)
fi

echo "[up.sh] script starting."

#Dietpi check ipset / iptables
apt install iptables ipset -y

. $SCRIPTS/base/firewall/get_gateway.sh

# IPSet Refference http://web-tech.ga-usa.com/2011/09/linux-geoip-firewall-via-iptables-using-ipset/index.html
# more: https://www.linuxjournal.com/content/advanced-firewall-configurations-ipset
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

if [[ $DEV_TYPE = "armv7l" ]] || [[ $DEV_TYPE = "aarch64" ]]; then
    # TODO: Check if SSHD exists, and add rules. https://linuxhint.com/check-if-ssh-is-running-on-linux/
    # allow SSH
    # Reff: https://www.digitalocean.com/community/tutorials/iptables-essentials-common-firewall-rules-and-commands#service-ssh
    iptables -A INPUT -s $GREEN -p tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -m comment --comment "apt, firewall, up.sh: allow SSH connections from GREEN" -j ACCEPT
    iptables -A OUTPUT -d $GREEN -p tcp --sport 22 -m conntrack --ctstate ESTABLISHED -m comment --comment "apt, firewall, up.sh: allow SSH connections from GREEN" -j ACCEPT
fi

# Allow ICMP out, but don't reply
iptables -A OUTPUT -p icmp --icmp-type 8 -d 0/0 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT -m comment --comment "apt, firewall, up.sh: Allow ICMP out, but dont reply"

# Allow Loopback
iptables -A INPUT -i lo -m comment --comment "apt, firewall, up.sh: Allow Loopback" -j ACCEPT
iptables -A OUTPUT -o lo -m comment --comment "apt, firewall, up.sh: Allow Loopback" -j ACCEPT

# Allow existing traffic
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -m comment --comment "apt, firewall, up.sh: Allow existing traffic" -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED -m comment --comment "apt, firewall, up.sh: Allow existing traffic" -j ACCEPT

# allow traffic out on port 53 -- DNS, added TCP to support apt-listbugs use of upgraded GLIBC (which needs TCP)
nameservers=$(grep -oP '(?<=^nameserver\s)\S+' /etc/resolv.conf)
for ns in $nameservers; do
  # Add firewall rules for each 
  iptables -A OUTPUT -d $ns -p udp --dport 53 -m comment --comment "apt, firewall, up.sh: Allow DNS via UDP for $ns" -j ACCEPT
  iptables -A OUTPUT -d $ns -p tcp --dport 53 -m comment --comment "apt, firewall, up.sh: Allow DNS via TCP for $ns" -j ACCEPT
done

# allow traffic out to port 123, NTP. This is in support of systemd-timesyncd which can orginate it's requests on any port. https://serverfault.com/a/1078454
iptables -A OUTPUT -m set ! --match-set BOGONS dst -p udp --dport 123 -j ACCEPT -m comment --comment "apt, firewall, up.sh: allow NTP out"

# allow traffic out for HTTP, HTTPS, or FTP
iptables -I OUTPUT -m set ! --match-set BOGONS dst -p tcp --dport 80 -m comment --comment "apt, firewall, up.sh: Allow HTTP out, except to BOGONS. APT Package manager." -j ACCEPT
iptables -I OUTPUT -m set ! --match-set BOGONS dst -p tcp --dport 443 -m comment --comment "apt, firewall, up.sh: Allow HTTPS out, except to BOGONS. APT Package manager." -j ACCEPT
iptables -I OUTPUT -m set ! --match-set BOGONS dst -p tcp --dport 21 -m comment --comment "apt, firewall, up.sh: Allow FTP out, except to BOGONS. APT Package manager." -j ACCEPT

# allow DHCP
iptables -A OUTPUT -p udp --sport 67:68 -m comment --comment "apt, firewall, up.sh: allow DHCP" -j ACCEPT

#Default Blocks
iptables -P OUTPUT DROP
iptables -P INPUT DROP

#Debian Iptables https://wiki.debian.org/iptables
#Persistance
#https://serverfault.com/questions/927673/iptables-restore-sometimes-fails-on-reboot
#https://askubuntu.com/questions/41400/how-do-i-make-the-script-to-run-automatically-when-tun0-interface-up-down-events
#iptables-save > /etc/iptables.up.rules
. $SCRIPTS/base/firewall/save.sh

# In LXC's for some reason this directory is missing.
if [ ! -d "/etc/network/if-pre-up.d" ]; then
  echo "/etc/network/if-pre-up.d does not exist, creating..."
  mkdir -p "/etc/network/if-pre-up.d"
fi

# heredoc, don't expand variables: https://stackoverflow.com/questions/27920806/how-to-avoid-heredoc-expanding-variables
cat <<'EOF'> /etc/network/if-pre-up.d/iptables
#!/bin/sh
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
  /sbin/iptables-restore < /etc/iptables.up.rules
fi
EOF
chmod +x /etc/network/if-pre-up.d/iptables
sed -i "s/ETH2/$ETH2/g" /etc/network/if-pre-up.d/iptables

if grep -q "12" /etc/os-release; then
cat <<EOT > /etc/systemd/system/network-pre-up.service
[Unit]
Description=Network Pre-Up Script

[Service]
Type=oneshot
ExecStart=/etc/network/if-pre-up.d/iptables

[Install]
WantedBy=network-pre.target
EOT
systemctl enable network-pre-up.service
systemctl start network-pre-up.service
fi

# Querry Anti-Scan IPtables rules
read -p "Add iptables Anti Port-Scanning? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
  # SNMP Setup
  . $SCRIPTS/base/firewall/anti-scan.sh
fi

echo "[up.sh] script complete."
