
## Network Pre-Up
### Sets default drops
### Enables early DHCP exception to default Drops
### Populates IPSets
### Restores IPTables Rules
### Run systemd service network-pre-up.service
### Runs scripts @ /etc/network/if-pre-up.d/lan-nic
ln -sf $SCRIPTS/base/firewall/network-pre-up.sh /etc/network/if-pre-up.d/lan-nic

ln -sf $SCRIPTS/base/firewall/ipset_BOGONS.sh /etc/network/if-pre-up.d/lan-nic.d/ipset_BOGONS.sh


## Network Up
### Checks gateway
### Checks DNS Servers
### Runs Scripts @ /etc/network/if-up.d/lan-nic.d/
ln -sf $SCRIPTS/base/firewall/network-up.sh /etc/network/if-up.d/lan-nic

ln -sf $SCRIPTS/base/firewall/ipset_builder.sh /etc/network/if-up.d/lan-nic.d/ipset_builder.sh

ln -sf $SCRIPTS/base/firewall/ipset_ntpservers.sh /etc/network/if-up.d/lan-nic.d/ipset_ntpservers.sh


# TROUBLESHOOT
journalctl -u networking
