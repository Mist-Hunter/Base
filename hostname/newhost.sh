#!/bin/bash
# Refference https://www.cyberciti.biz/faq/ubuntu-18-04-lts-change-hostname-permanently/
# DietPi: https://github.com/MichaIng/DietPi/blob/dev/dietpi/func/change_hostname
# Usage ./newhost.sh <NEW HOSTNAME>

set -e

current_host=$(hostname)

# Prompt if no parameters passed
if [[ $# -eq 0 ]]; then
   read -p "apt, hostname, newhost.sh: No hostname provided. Please enter new hostname: " new_host
else
   new_host=$1
   echo "apt, hostname, newhost.sh: Received $new_host from CLI parameter"  
fi

# Check character count and re-prompt if too long
while true; do
  if [[ ${#new_host} -le 63 ]]; then
    break
  else
    echo "The hostname must be 63 characters or less, try again."
    read -p "apt, hostname, newhost.sh: Please enter a new hostname (63 characters or less): " new_host
  fi
done

# Check and update postfix config if present
if [[ -f /etc/postfix/sasl_passwd ]]; then
  if grep -q "mydestination = .*$current_host" /etc/postfix/sasl_passwd; then
    sed -i "s/mydestination = .*$current_host/mydestination = $new_host, localhost.lan, localhost/" /etc/postfix/sasl_passwd
    echo "apt, hostname, newhost.sh: Updated postfix configuration in /etc/postfix/sasl_passwd"
  elif grep -q "mydestination = " /etc/postfix/sasl_passwd; then
    sed -i "s/mydestination = .*/mydestination = $new_host, localhost.lan, localhost/" /etc/postfix/sasl_passwd
    echo "apt, hostname, newhost.sh: Updated postfix configuration in /etc/postfix/sasl_passwd"
  else
    echo "mydestination = $new_host, localhost.lan, localhost" >> /etc/postfix/sasl_passwd
    echo "apt, hostname, newhost.sh: Added mydestination to /etc/postfix/sasl_passwd"
  fi
else
  echo "apt, hostname, newhost.sh: /etc/postfix/sasl_passwd not found, skipping postfix configuration"
fi

# Update /etc/environment
if grep -q "export HOST_NAME=" /etc/environment; then
   sed -i "s/export HOST_NAME=.*/export HOST_NAME=$new_host/" /etc/environment
else
   echo "# Hostname"  >> /etc/environment
   echo "export HOST_NAME=$new_host" >> /etc/environment
   echo
fi
echo "apt, hostname, newhost.sh: Updated /etc/environment"

# Update /etc/hosts
if grep -q "$current_host" /etc/hosts; then
  sed -i "s/$current_host/$new_host/g" /etc/hosts
  echo "apt, hostname, newhost.sh: Replaced current hostname in /etc/hosts"
else
  sed -i "1s/$/ $new_host/" /etc/hosts
  echo "apt, hostname, newhost.sh: Added new hostname to /etc/hosts"
fi

# Set new hostname
hostnamectl set-hostname "$new_host"

# Create disk label file
disk_dev=$(df -P . | sed -n '$s/[[:blank:]].*//p')
disk_label="$new_host"
echo "Disk device: $disk_dev, Label: $disk_label"
e2label "$disk_dev" "$disk_label"

# Create info file
cat <<EOT > "/Disk-$disk_label.md"
$(date)
# Hostname
**$(hostname)**
# Disks
$(lsblk)
EOT

# Verify hostname change
ping -c 3 "$new_host"

if grep -q "$new_host" /etc/hosts; then
   echo "Hostname change successful";
else
   echo "Hostname change unsuccessful";
   echo "127.0.0.1       $(hostname)" >> /etc/hosts
fi

export HOST_NAME=$new_host