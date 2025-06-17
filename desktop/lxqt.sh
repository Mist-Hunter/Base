#!/bin/bash
# https://wiki.debian.org/LXQt
# https://packages.debian.org/search?suite=trixie&keywords=sddm

apt remove libpam-passwdqc
apt install lxqt-core xserver-xorg-core xserver-xorg xinit

passwd user
echo "exec startlxqt" > ~/.xinitrc

# Set Theme
#cp ~/.config/lxqt/lxqt.conf ~/.config/lxqt/lxqt.conf.backup
sed -i -E '/^\[General\]$/,/^\[/ { /^\s*theme\s*=/ s/=.*/=ambiance/ }' ~/.config/lxqt/lxqt.conf
