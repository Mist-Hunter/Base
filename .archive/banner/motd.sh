#!/bin/bash
apt install figlet lolcat -y
git clone https://github.com/yboetz/motd.git 
cd motd
cp 10-hostname-color /etc/update-motd.d/
# cp 20-sysinfo /etc/update-motd.d/
cp 35-diskspace /etc/update-motd.d/
#cp 40-services /etc/update-motd.d/
#cp 50-fail2ban /etc/update-motd.d/
#cp 50-fail2ban-status /etc/update-motd.d/
#cp 60-docker /etc/update-motd.d/
cd ..
rm -rd motd
mv /etc/motd /etc/motd.original
sed -i 's/services=("fail2ban" "ufw" "lxd" "netdata" "zed" "smartd" "postfix")/services=("fail2ban" "ufw" "netdata")/' /etc/update-motd.d/40-services
