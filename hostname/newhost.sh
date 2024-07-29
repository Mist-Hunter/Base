#!/bin/bash
# Refference https://www.cyberciti.biz/faq/ubuntu-18-04-lts-change-hostname-permanently/
# DietPi: https://github.com/MichaIng/DietPi/blob/dev/dietpi/func/change_hostname
# Usage ./newhost.sh <NEW HOSTNAME>

# Default Hostname

current_host=$(hostname)

# Prompt if not parameters passed.
if [ $# -eq 0 ]; then
   read -p "apt, hostname, newhost.sh: No hostname provided, Please enter new hostname: " hostname
   new_host=$hostname
else
   new_host=$1
   echo "apt, hostname, newhost.sh: Recieved $new_host from CLI parameter"   
fi

# Check character count and re-offer if too long, was set to 16, ChatGPT claims 63 is fine
while true; do
  if [ ${#new_host} -le 63 ]; then
    break
  else
    echo "The hostname must be less than or equal to 16 characters, try again."
    read -p "apt, hostname, newhost.sh: The hostname must be less than or equal to 16 characters, Please enter new hostname: " hostname
  fi
done

#TODO: check hostname in postfix config
#TODO: Remove hostname edit in bashrc

if grep -q "$new_host" /etc/hosts
then
   echo "apt, hostname, newhost.sh: current hostname in localhosts, replacing"
   sed -i "s/$current_host/$new_host/g" /etc/hosts
else
echo "apt, hostname, newhost.sh: current hostname NOT in localhosts, adding"
#https://stackoverflow.com/questions/35444122/append-output-of-hostname-command-to-etc-hosts
sed -i "1s/$/ $(echo $new_host | tr '\n' ' ')/" /etc/hosts
sed -i "s|export HOST_NAME=$(hostname)|export HOST_NAME=$new_host|g" /root/.bashrc

# Touch file in /root so that disk owner is apparent when mounting through a different OS (Example: Eset Live Scan)
disk_dev=$(df -P . | sed -n '$s/[[:blank:]].*//p') 
disk_label="$new_host" # Adding the date makes the name too long. "-$(printf '%(%Y%m%d)T\n' -1)""

#DEBUG
echo "$disk_dev and $disk_label"

e2label $disk_dev $disk_label # "-root"-$(echo $disk_dev | cut -c 6-) <--- Can't fit. Label is too short. 16 characters max

cat <<"EOT" > /"Disk-$disk_label.md"
$(date)

# Hostname
**$(hostname)**

# Disks
$(lsblk)

EOT
fi
hostnamectl set-hostname $new_host
# lsblk -o name,mountpoint,label,size

# cat /etc/hosts | grep $new_host

ping -c 3 $new_host
if cat /etc/hosts | grep -q $new_host
then
   echo "OK";
else
   echo "NOT OK";
   echo "127.0.0.1       $(hostname)" >> /etc/hosts
fi