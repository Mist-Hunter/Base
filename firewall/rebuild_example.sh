#!/bin/bash

# IP Tables Rebuild

# Restic
iptables -A OUTPUT -d $REV_PROXY -p tcp --dport 2222 -m comment --comment "Debian-Base, up.sh: allow Restic outbound SFTP to reverse proxy" -j ACCEPT

# Allow ICMP out, but don't reply
# iptables -I INPUT -j DROP -p icmp --icmp-type echo-request -m comment --comment "DebSec, firewall.sh: Allow ICMP out, but don't reply"
iptables -A OUTPUT -p icmp --icmp-type 8 -d 0/0 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT -m comment --comment "DebSec, firewall.sh: Allow ICMP out, but don't reply"

# Allow Loopback
iptables -A INPUT -i lo -m comment --comment "DebSec, firewall.sh: Allow Loopback" -j ACCEPT
iptables -A OUTPUT -o lo -m comment --comment "DebSec, firewall.sh: Allow Loopback" -j ACCEPT

# Allow existing traffic
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -m comment --comment "DebSec, firewall.sh: Allow existing traffic" -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED -m comment --comment "DebSec, firewall.sh: Allow existing traffic" -j ACCEPT

# allow traffic out on port 53 -- DNS
iptables -A OUTPUT -p udp --dport 53 -m comment --comment "DebSec, firewall.sh: allow DNS calls out" -j ACCEPT

# allow traffic out on port 123 -- NTP
iptables -A OUTPUT -m set ! --match-set BOGONS dst -p udp --sport 123 --dport 123 -j ACCEPT -m comment --comment "DebSec, firewall.sh: allow NTP out"

# allow traffic out for HTTP, HTTPS, or FTP
# apt might needs these depending on which sources you're using
iptables -I OUTPUT -m set ! --match-set BOGONS dst -p tcp --dport 80 -m comment --comment "DebSec, firewall.sh: Allow HTTP out, except to BOGONS. APT Package manager." -j ACCEPT
iptables -I OUTPUT -m set ! --match-set BOGONS dst -p tcp --dport 443 -m comment --comment "DebSec, firewall.sh: Allow HTTPS out, except to BOGONS. APT Package manager." -j ACCEPT
iptables -I OUTPUT -m set ! --match-set BOGONS dst -p tcp --dport 21 -m comment --comment "DebSec, firewall.sh: Allow FTP out, except to BOGONS. APT Package manager." -j ACCEPT

# allow DHCP
iptables -A OUTPUT -p udp --sport 67:68 -m comment --comment "DebSec, firewall.sh: allow DHCP" -j ACCEPT

#Allow local Gogs server access
iptables -I OUTPUT -d $REV_PROXY -p tcp --dport 80 -m comment --comment "DebSec, Firewall/up.sh: allow HTTP traffic to reverse proxy, local GIT Server." -j ACCEPT

#Default Blocks
iptables -P OUTPUT DROP
iptables -P INPUT DROP

#Allow Email
iptables -A OUTPUT -p tcp --dport $SMTP_PORT -j ACCEPT -m comment --comment "DebSec, email.sh: allow Postfix Mail Server, Outbound Mail"

# allow SSH
iptables -A INPUT -p tcp -s $GREEN --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -m comment --comment "DebSec, firewall.sh: allow SSH connections from GREEN" -j ACCEPT
iptables -A OUTPUT -p tcp -d $GREEN --sport 22 -m conntrack --ctstate ESTABLISHED -m comment --comment "DebSec, firewall.sh: allow SSH connections from GREEN" -j ACCEPT

# Block Docker & DMZ to RFC1918
iptables -I DOCKER-USER -s $DOCKER_SUBNET -m set --match-set BOGONS dst  -m comment --comment "Docker, up.sh: Allow Docker Networking Out" -j DROP

# Block RFC1918 to Docker & DMZ 
iptables -I DOCKER-USER -m set --match-set BOGONS src -d $DOCKER_SUBNET -m comment --comment "Docker, up.sh: Allow Docker Networking Out" -j DROP

# Docker, Local Exceptions
iptables -I DOCKER-USER -s $GREEN -m comment --comment "Docker, up.sh: Allow GREEN" -j RETURN
iptables -I DOCKER-USER -s $REV_PROXY -m comment --comment "Docker, up.sh: Allow HAProxy" -j RETURN
iptables -I DOCKER-USER -d $GREEN -m comment --comment "Docker, up.sh: Allow GREEN" -j RETURN
iptables -I DOCKER-USER -d $REV_PROXY -m comment --comment "Docker, up.sh: Allow HAProxy" -j RETURN
iptables -A DOCKER-USER -j RETURN

iptables-save > /etc/iptables.up.rules
