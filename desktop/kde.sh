#!/bin/bash

# Full https://packages.debian.org/trixie/plasma-desktop
#apt install plasma-desktop sddm


# Medium
apt install plasma-desktop sddm --no-install-recommends
apt install plasma-desktop emptty --no-install-recommends

# Minimal
apt remove libpam-passwdqc
apt install --no-install-recommends \
    xserver-xorg-core \
    xinit \
    plasma-workspace \
    kwin-x11 \
    konsole \
    frameworkintegration \
    polkit-kde-agent-1 \
    kscreen \
    powerdevil


apt install kactivities-bin


killall kdeconnectd
apt remove kdeconnect -y
apt autoremove -y