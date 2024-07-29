#!/bin/bash
# apt-listbugs \ # Was blocking LVM2

export DEBIAN_FRONTEND=noninteractive

#https://packages.debian.org/bullseye/apt-listbugs , https://manpages.debian.org/testing/apt-listbugs/apt-listbugs.1.en.html
#https://packages.debian.org/bullseye/apt-listchanges
#https://packages.debian.org/bullseye/needrestart
#https://wiki.debian.org/DebianSecurity/debsecan
#https://wiki.debian.org/CheckingDebsums
#https://packages.debian.org/sid/libpam-tmpdir
#libpam-usb \ #https://wiki.debian.org/pamusb
#checkrestart \

apt install -y \
apt-listbugs \
apt-listchanges \
needrestart \
debsecan \
debsums \
libpam-tmpdir \
sysstat

# Needrestart, automatic, https://medium.com/@nobuto_m/knowing-what-services-need-restart-with-needrestart-37419f44ed46
sed -i "s/#\$nrconf{restart} = 'i';/\$nrconf{restart} = 'a';/g" /etc/needrestart/needrestart.conf